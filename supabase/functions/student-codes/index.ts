// supabase/functions/student-codes/index.ts
//
// Penerbitan & pencabutan kode akses siswa. SEMUA pembuatan kode terjadi di
// server memakai CSPRNG (crypto.getRandomValues) — tidak pernah dari client.
//
// Body:
//   { "action": "issue", "kelas_id": "<uuid>", "siswa_id": "<uuid|null>",
//     "single_use": true, "expires_in_days": 30, "note": "..." }
//   { "action": "revoke", "id": "<uuid>" }
//
// Otorisasi (diverifikasi ulang di server terhadap tabel profiles):
//   * admin  → semua kelas
//   * guru   → hanya kelas yang menjadi tanggung jawabnya
//              (wali kelas, punya jadwal, atau terdaftar di guru_mapel)
//
// Kode tidak disimpan plaintext: hanya SHA-256 + 6 karakter pertama.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Tanpa karakter ambigu (0/O, 1/I/L) agar mudah dibaca & diketik siswa.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 10;
const MAX_CODE_ATTEMPTS = 6;

interface JsonMap {
  [key: string]: unknown;
}

function json(status: number, payload: JsonMap): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeCode(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// CSPRNG dengan rejection sampling: `b % 30` saja akan bias karena
// 256 bukan kelipatan 30. Buang byte di atas batas agar tiap karakter
// punya peluang yang sama.
function randomCode(): string {
  const max = Math.floor(256 / CODE_ALPHABET.length) * CODE_ALPHABET.length; // 240
  let out = "";
  while (out.length < CODE_LENGTH) {
    const bytes = new Uint8Array(CODE_LENGTH);
    crypto.getRandomValues(bytes);
    for (const b of bytes) {
      if (b >= max) continue;
      out += CODE_ALPHABET[b % CODE_ALPHABET.length];
      if (out.length === CODE_LENGTH) break;
    }
  }
  return `EDT-${out.slice(0, 5)}-${out.slice(5)}`;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed. Gunakan POST.", code: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("student-codes: konfigurasi server belum lengkap");
    return json(500, { error: "Server misconfigured.", code: "server_misconfigured" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json(401, { error: "Perlu login admin/guru.", code: "unauthorized" });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    const user = userData?.user;
    if (userErr || !user) {
      return json(401, { error: "Sesi tidak valid. Login ulang.", code: "unauthorized" });
    }

    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("id, role, is_active, full_name")
      .eq("id", user.id)
      .maybeSingle();

    if (profileErr) {
      console.error("student-codes: gagal membaca profil", profileErr.code);
      return json(500, { error: "Gagal memverifikasi akun.", code: "lookup_failed" });
    }
    if (!profile || profile.is_active !== true) {
      return json(403, { error: "Akun tidak aktif.", code: "forbidden" });
    }

    const role = String(profile.role ?? "");
    if (role !== "admin" && role !== "guru") {
      return json(403, { error: "Hanya admin/guru yang boleh mengelola kode.", code: "forbidden" });
    }

    let parsed: unknown;
    try {
      parsed = await req.json();
    } catch (_) {
      return json(400, { error: "Body harus JSON yang valid.", code: "invalid_json" });
    }
    if (typeof parsed !== "object" || parsed === null) {
      return json(400, { error: "Body harus berupa objek JSON.", code: "invalid_json" });
    }
    const body = parsed as JsonMap;
    const action = String(body.action ?? "").trim().toLowerCase();

    // Helper: apakah guru berwenang atas kelas?
    const canHandleKelas = async (kelasId: string): Promise<boolean> => {
      if (role === "admin") return true;
      const { data: wali } = await admin
        .from("kelas")
        .select("id")
        .eq("id", kelasId)
        .eq("wali_kelas_id", user.id)
        .maybeSingle();
      if (wali) return true;

      const { data: jadwal } = await admin
        .from("jadwal_pelajaran")
        .select("id")
        .eq("kelas_id", kelasId)
        .eq("guru_id", user.id)
        .limit(1);
      if (jadwal && jadwal.length > 0) return true;

      const { data: gm } = await admin
        .from("guru_mapel")
        .select("id")
        .eq("kelas_id", kelasId)
        .eq("guru_id", user.id)
        .limit(1);
      return !!(gm && gm.length > 0);
    };

    const writeAudit = async (actionName: string, entityId: string, detail: JsonMap) => {
      try {
        await admin.from("audit_log").insert({
          actor_id: user.id,
          actor_role: role,
          action: actionName,
          entity: "kode_akses_siswa",
          entity_id: entityId,
          detail,
        });
      } catch (_) {
        // audit tidak boleh menggagalkan operasi utama
      }
    };

    // ------------------------- ISSUE -------------------------
    if (action === "issue") {
      const kelasId = String(body.kelas_id ?? "").trim();
      const siswaIdRaw = body.siswa_id;
      const siswaId = siswaIdRaw === null || siswaIdRaw === undefined || siswaIdRaw === ""
        ? null
        : String(siswaIdRaw).trim();
      const singleUse = body.single_use === undefined ? true : body.single_use === true;
      const expiresInDaysRaw = body.expires_in_days;
      const note = String(body.note ?? "").trim().slice(0, 200);

      if (!isUuid(kelasId)) {
        return json(400, { error: "kelas_id tidak valid.", code: "invalid_kelas" });
      }
      if (siswaId !== null && !isUuid(siswaId)) {
        return json(400, { error: "siswa_id tidak valid.", code: "invalid_siswa" });
      }

      let expiresAt: string | null = null;
      if (expiresInDaysRaw !== undefined && expiresInDaysRaw !== null && expiresInDaysRaw !== "") {
        const days = Number(expiresInDaysRaw);
        if (!Number.isFinite(days) || days < 1 || days > 365) {
          return json(400, { error: "Masa berlaku harus 1–365 hari.", code: "invalid_expiry" });
        }
        expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
      }

      const { data: kelas } = await admin
        .from("kelas")
        .select("id, nama_kelas")
        .eq("id", kelasId)
        .maybeSingle();
      if (!kelas) {
        return json(404, { error: "Kelas tidak ditemukan.", code: "kelas_not_found" });
      }
      if (!(await canHandleKelas(kelasId))) {
        return json(403, {
          error: "Anda tidak berwenang menerbitkan kode untuk kelas ini.",
          code: "forbidden",
        });
      }

      if (siswaId) {
        const { data: siswa } = await admin
          .from("siswa")
          .select("id, kelas_id, status_aktif")
          .eq("id", siswaId)
          .maybeSingle();
        if (!siswa) {
          return json(404, { error: "Siswa tidak ditemukan.", code: "siswa_not_found" });
        }
        if (siswa.kelas_id !== kelasId) {
          return json(400, {
            error: "Siswa tidak terdaftar pada kelas yang dipilih.",
            code: "kelas_mismatch",
          });
        }
        if (siswa.status_aktif !== true) {
          return json(400, { error: "Siswa tidak aktif.", code: "siswa_inactive" });
        }
      }

      let generated = "";
      let inserted: JsonMap | null = null;
      for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
        generated = randomCode();
        const kodeHash = await sha256Hex(normalizeCode(generated));
        const { data, error } = await admin
          .from("kode_akses_siswa")
          .insert({
            kode_hash: kodeHash,
            kode_prefix: generated.slice(0, 7), // "EDT-XXX"
            kelas_id: kelasId,
            siswa_id: siswaId,
            single_use: singleUse,
            expires_at: expiresAt,
            created_by: user.id,
            note: note || null,
          })
          .select("id, kode_prefix, kelas_id, siswa_id, single_use, status, expires_at, created_at")
          .single();

        if (!error && data) {
          inserted = data as JsonMap;
          break;
        }
        if (error && error.code !== "23505") {
          console.error("student-codes: insert gagal", error.code);
          return json(500, { error: "Gagal membuat kode.", code: "insert_failed" });
        }
      }

      if (!inserted) {
        return json(500, { error: "Gagal membuat kode unik. Coba lagi.", code: "insert_failed" });
      }

      await writeAudit("issue", String(inserted.id), {
        kelas_id: kelasId,
        siswa_id: siswaId,
        single_use: singleUse,
        expires_at: expiresAt,
      });

      return json(200, {
        success: true,
        kode: generated,
        data: inserted,
      });
    }

    // ------------------------- REVOKE -------------------------
    if (action === "revoke") {
      const id = String(body.id ?? "").trim();
      if (!isUuid(id)) {
        return json(400, { error: "id tidak valid.", code: "invalid_id" });
      }

      const { data: row, error: rowErr } = await admin
        .from("kode_akses_siswa")
        .select("id, kelas_id, status")
        .eq("id", id)
        .maybeSingle();

      if (rowErr || !row) {
        return json(404, { error: "Kode tidak ditemukan.", code: "not_found" });
      }
      if (!(await canHandleKelas(String(row.kelas_id)))) {
        return json(403, { error: "Anda tidak berwenang atas kode ini.", code: "forbidden" });
      }
      if (row.status === "revoked") {
        return json(200, { success: true, already_revoked: true });
      }

      const { error: updateErr } = await admin
        .from("kode_akses_siswa")
        .update({ status: "revoked", revoked_at: new Date().toISOString() })
        .eq("id", id);

      if (updateErr) {
        console.error("student-codes: revoke gagal", updateErr.code);
        return json(500, { error: "Gagal mencabut kode.", code: "update_failed" });
      }

      await writeAudit("revoke", id, {});
      return json(200, { success: true });
    }

    return json(400, { error: "action harus 'issue' atau 'revoke'.", code: "invalid_action" });
  } catch (e) {
    console.error("student-codes: unexpected", e instanceof Error ? e.message : String(e));
    return json(500, { error: "Terjadi kesalahan internal pada server.", code: "internal_error" });
  }
});
