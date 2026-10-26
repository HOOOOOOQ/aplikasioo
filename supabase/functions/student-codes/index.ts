// supabase/functions/student-codes/index.ts
//
// Penerbitan & pencabutan kode akses siswa. SEMUA pembuatan kode terjadi di
// server memakai CSPRNG (crypto.getRandomValues) — tidak pernah dari client.
//
// Body:
//   { "action": "issue", "kelas_id": "<uuid>", "siswa_id": "<uuid|null>",
//     "single_use": true, "expires_in_days": 30, "note": "..." }
//   { "action": "revoke", "id": "<uuid>" }
//   { "action": "status", "idempotency_key": "<uuid>" }  // cek hasil penerbitan
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

/**
 * Ambil token mentah dari "Authorization: Bearer <jwt>".
 *
 * Token harus dikirim eksplisit ke GoTrue saat verifikasi. Versi lama function
 * ini membuat client dengan `global.headers.Authorization` lalu memanggil
 * `auth.getUser()` TANPA argumen. Pada @supabase/supabase-js 2.39.0,
 * `getUser()` tidak membaca header global tersebut: karena `persistSession`
 * dimatikan, client tidak punya session di storage dan langsung mengembalikan
 * `AuthSessionMissingError`. Akibatnya SEMUA permintaan admin yang sah ditolak
 * dengan 401 "Sesi tidak valid. Login ulang." — bukan karena sesi kedaluwarsa.
 *
 * Perbaikan: token diverifikasi dengan `getUser(token)` (pola yang sama dengan
 * create-teacher), sehingga signature, masa berlaku, dan status sesi benar-benar
 * divalidasi oleh GoTrue.
 */
function extractBearerToken(headerValue: string | null): string {
  if (!headerValue) return "";
  const value = headerValue.trim();
  const match = /^Bearer\s+(.+)$/i.exec(value);
  return (match ? match[1] : value).trim();
}

/**
 * Deteksi error PostgREST/PostgreSQL yang berarti objek database belum ada
 * (migration belum dijalankan) atau schema cache masih basi.
 *
 * PGRST205 = tabel tidak ada di schema cache, PGRST202 = fungsi tidak ada,
 * 42P01 = undefined_table, 42883 = undefined_function.
 */
function isSchemaMissing(error: { code?: string; message?: string } | null | undefined): boolean {
  if (!error) return false;
  const code = String(error.code ?? "");
  if (["PGRST205", "PGRST202", "42P01", "42883"].includes(code)) return true;
  const msg = String(error.message ?? "").toLowerCase();
  return msg.includes("could not find the table") ||
    msg.includes("could not find the function") ||
    msg.includes("schema cache") ||
    (msg.includes("relation") && msg.includes("does not exist"));
}

/** Jawaban standar bila migration kode akses belum diterapkan. */
function schemaNotReadyResponse(): Response {
  return json(503, {
    error:
      "Skema kode akses belum tersedia di database. Jalankan migration " +
      "supabase/migrations/005_access_codes_schema_repair.sql di project Supabase Anda.",
    code: "schema_not_ready",
  });
}

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

  const bearerToken = extractBearerToken(req.headers.get("Authorization"));
  if (!bearerToken) {
    return json(401, {
      error: "Permintaan tidak menyertakan token login. Masuk kembali sebagai admin/guru.",
      code: "missing_token",
    });
  }

  // anonKey tetap dipakai sebagai apikey pada client verifikasi agar konsisten
  // dengan konfigurasi project. Token pengguna TIDAK ditaruh di header global:
  // token dikirim eksplisit ke getUser(token) di bawah.
  const verifier = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    const { data: userData, error: userErr } = await verifier.auth.getUser(bearerToken);
    const user = userData?.user;
    if (userErr || !user) {
      // Hanya metadata aman yang dicatat — tanpa token, tanpa email.
      const message = (userErr?.message ?? "user null").toLowerCase();
      console.warn("student-codes: verifikasi token gagal:", userErr?.status ?? "-");

      if (message.includes("api key") || message.includes("apikey")) {
        // Kesalahan konfigurasi server (SUPABASE_URL vs SERVICE_ROLE_KEY beda project).
        return json(500, {
          error: "Konfigurasi server tidak cocok dengan project Supabase.",
          code: "server_misconfigured",
        });
      }

      const expired = message.includes("expired") ||
        message.includes("token has expired") ||
        message.includes("jwt expired");

      return json(401, {
        error: expired
          ? "Sesi login sudah kedaluwarsa. Masuk kembali."
          : "Sesi login tidak valid. Masuk kembali.",
        code: expired ? "session_expired" : "invalid_token",
      });
    }

    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("id, role, is_active, full_name")
      .eq("id", user.id)
      .maybeSingle();

    if (profileErr) {
      console.error("student-codes: gagal membaca profil", profileErr.code);
      if (isSchemaMissing(profileErr)) {
        return json(503, {
          error: "Tabel profiles belum tersedia di database.",
          code: "schema_not_ready",
        });
      }
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
        const { error } = await admin.from("audit_log").insert({
          actor_id: user.id,
          actor_role: role,
          action: actionName,
          entity: "kode_akses_siswa",
          entity_id: entityId,
          detail,
        });
        if (error) {
          // audit tidak menggagalkan operasi utama, tetapi tetap dicatat di log server.
          console.warn("student-codes: audit gagal", error.code);
        }
      } catch (_) {
        // jangan pernah menggagalkan operasi utama karena audit
      }
    };

    // ------------------------- STATUS -------------------------
    // Dipakai saat aplikasi timeout/tidak yakin apakah penerbitan berhasil.
    // Tidak pernah membuat kode baru — hanya melaporkan baris yang sudah ada.
    if (action === "status") {
      const key = String(body.idempotency_key ?? "").trim();
      if (!isUuid(key)) {
        return json(400, { error: "idempotency_key tidak valid.", code: "invalid_id" });
      }
      const { data: row, error: rowErr } = await admin
        .from("kode_akses_siswa")
        .select("id, kode_prefix, kelas_id, siswa_id, single_use, status, expires_at, created_at, created_by")
        .eq("idempotency_key", key)
        .maybeSingle();

      if (rowErr) {
        console.error("student-codes: status gagal", rowErr.code);
        if (isSchemaMissing(rowErr)) return schemaNotReadyResponse();
        return json(500, { error: "Gagal memeriksa status kode.", code: "lookup_failed" });
      }
      if (!row) return json(200, { success: true, found: false });
      if (row.created_by !== user.id && role !== "admin") {
        return json(403, { error: "Anda tidak berwenang atas kode ini.", code: "forbidden" });
      }
      // Kode plaintext TIDAK disimpan, jadi tidak bisa dikirim ulang.
      return json(200, { success: true, found: true, data: row, kode: null });
    }

    // ------------------------- ISSUE -------------------------
    if (action === "issue") {
      const kelasId = String(body.kelas_id ?? "").trim();
      const idempotencyKeyRaw = String(body.idempotency_key ?? "").trim();
      const idempotencyKey = idempotencyKeyRaw === "" ? null : idempotencyKeyRaw;
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
      if (idempotencyKey !== null && !isUuid(idempotencyKey)) {
        return json(400, { error: "idempotency_key tidak valid.", code: "invalid_id" });
      }

      let expiresAt: string | null = null;
      if (expiresInDaysRaw !== undefined && expiresInDaysRaw !== null && expiresInDaysRaw !== "") {
        const days = Number(expiresInDaysRaw);
        if (!Number.isFinite(days) || days < 1 || days > 365) {
          return json(400, { error: "Masa berlaku harus 1–365 hari.", code: "invalid_expiry" });
        }
        expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
      }

      const { data: kelas, error: kelasErr } = await admin
        .from("kelas")
        .select("id, nama_kelas")
        .eq("id", kelasId)
        .maybeSingle();
      if (kelasErr) {
        console.error("student-codes: gagal membaca kelas", kelasErr.code);
        if (isSchemaMissing(kelasErr)) return schemaNotReadyResponse();
        return json(500, { error: "Gagal membaca data kelas.", code: "lookup_failed" });
      }
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

      // Idempotency: bila kunci ini sudah dipakai, JANGAN buat kode kedua.
      if (idempotencyKey) {
        const { data: existing, error: existingErr } = await admin
          .from("kode_akses_siswa")
          .select("id, kode_prefix, kelas_id, siswa_id, single_use, status, expires_at, created_at")
          .eq("idempotency_key", idempotencyKey)
          .maybeSingle();

        if (existingErr && !isSchemaMissing(existingErr)) {
          console.error("student-codes: cek idempotency gagal", existingErr.code);
          return json(500, { error: "Gagal memeriksa kode sebelumnya.", code: "lookup_failed" });
        }
        if (existing) {
          return json(200, {
            success: true,
            duplicate: true,
            kode: null,
            data: existing,
            message: "Kode untuk permintaan ini sudah terbit sebelumnya dan tidak dapat ditampilkan ulang.",
          });
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
            idempotency_key: idempotencyKey,
          })
          .select("id, kode_prefix, kelas_id, siswa_id, single_use, status, expires_at, created_at")
          .single();

        if (!error && data) {
          inserted = data as JsonMap;
          break;
        }
        if (error && error.code !== "23505") {
          console.error("student-codes: insert gagal", error.code);
          if (isSchemaMissing(error)) return schemaNotReadyResponse();
          return json(500, { error: "Gagal membuat kode.", code: "insert_failed" });
        }
        if (error && error.code === "23505" && idempotencyKey) {
          // Balapan dua permintaan dengan kunci sama: yang kalah melaporkan
          // kode yang sudah tersimpan, bukan membuat kode baru.
          const { data: existing } = await admin
            .from("kode_akses_siswa")
            .select("id, kode_prefix, kelas_id, siswa_id, single_use, status, expires_at, created_at")
            .eq("idempotency_key", idempotencyKey)
            .maybeSingle();
          if (existing) {
            return json(200, { success: true, duplicate: true, kode: null, data: existing });
          }
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

      if (rowErr) {
        console.error("student-codes: revoke lookup gagal", rowErr.code);
        if (isSchemaMissing(rowErr)) return schemaNotReadyResponse();
        return json(500, { error: "Gagal membaca kode.", code: "lookup_failed" });
      }
      if (!row) {
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
        if (isSchemaMissing(updateErr)) return schemaNotReadyResponse();
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
