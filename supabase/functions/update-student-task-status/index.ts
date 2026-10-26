// supabase/functions/update-student-task-status/index.ts
//
// Endpoint aman untuk siswa menandai status tugasnya sendiri (tanpa login).
//
// Perbaikan keamanan:
// - Versi lama: jika header/field token KOSONG, validasi dilewati sama sekali;
//   token base64 juga bisa dipalsukan. Artinya siapa pun bisa mengubah status tugas siapa pun.
// - Sekarang: token WAJIB, harus bertanda tangan HMAC-SHA256 dari student-access,
//   belum kedaluwarsa, dan subjeknya harus sama dengan siswa_id.
//
// Secret: STUDENT_TOKEN_SECRET (disarankan) atau fallback SUPABASE_SERVICE_ROLE_KEY.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function hmac(payload: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  return base64url(new Uint8Array(sig));
}

/** Perbandingan waktu-konstan sederhana untuk mencegah timing attack. */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed. Gunakan POST.", code: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY") ?? "";
  const tokenSecret = Deno.env.get("STUDENT_TOKEN_SECRET") ?? serviceRoleKey;

  if (!supabaseUrl || !serviceRoleKey || !tokenSecret) {
    console.error("update-student-task-status: secret server belum lengkap");
    return json(500, { error: "Server misconfigured.", code: "server_misconfigured" });
  }

  try {
    let parsed: unknown;
    try {
      parsed = await req.json();
    } catch (_) {
      return json(400, { error: "Body harus JSON yang valid.", code: "invalid_json" });
    }
    if (typeof parsed !== "object" || parsed === null) {
      return json(400, { error: "Body harus berupa objek JSON.", code: "invalid_json" });
    }

    const body = parsed as Record<string, unknown>;
    const tugasId = String(body.tugas_id ?? "").trim();
    const siswaId = String(body.siswa_id ?? "").trim();
    const status = String(body.status ?? "").trim();
    const token = String(body.token ?? "").trim();

    if (!tugasId || !siswaId || !status) {
      return json(400, { error: "tugas_id, siswa_id, status wajib diisi", code: "missing_fields" });
    }
    if (!["selesai", "belum_selesai"].includes(status)) {
      return json(400, { error: "status tidak valid", code: "invalid_status" });
    }

    // ===== Token WAJIB. Tidak ada lagi jalur "tanpa token". =====
    if (!token) {
      return json(401, {
        error: "Token akses siswa wajib. Verifikasi ulang kode siswa di aplikasi.",
        code: "student_token_missing",
      });
    }

    const parts = token.split(".");
    if (parts.length !== 3) {
      return json(401, {
        error: "Token tidak valid. Verifikasi ulang kode siswa di aplikasi.",
        code: "student_token_invalid",
      });
    }
    const [tokenSiswaId, expRaw, signature] = parts;
    const exp = Number(expRaw);
    if (!Number.isFinite(exp) || exp * 1000 < Date.now()) {
      return json(401, {
        error: "Token kedaluwarsa. Verifikasi ulang kode siswa di aplikasi.",
        code: "student_token_expired",
      });
    }

    const expected = await hmac(`${tokenSiswaId}.${expRaw}`, tokenSecret);
    if (!safeEqual(expected, signature)) {
      return json(401, { error: "Token tidak valid.", code: "student_token_invalid" });
    }
    if (tokenSiswaId !== siswaId) {
      return json(403, {
        error: "Token tidak sesuai dengan siswa_id",
        code: "token_mismatch",
      });
    }

    const client = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: siswa, error: siswaErr } = await client
      .from("siswa")
      .select("id, kelas_id, status_aktif")
      .eq("id", siswaId)
      .maybeSingle();
    if (siswaErr) {
      console.error("update-student-task-status: query siswa gagal", siswaErr.code);
      return json(500, { error: "Gagal memeriksa data siswa.", code: "lookup_failed" });
    }
    if (!siswa || siswa.status_aktif !== true) {
      return json(404, { error: "Siswa tidak ditemukan atau tidak aktif", code: "not_found" });
    }

    const { data: tugas, error: tugasErr } = await client
      .from("tugas")
      .select("id, kelas_id, status_publikasi")
      .eq("id", tugasId)
      .maybeSingle();
    if (tugasErr) {
      console.error("update-student-task-status: query tugas gagal", tugasErr.code);
      return json(500, { error: "Gagal memeriksa data tugas.", code: "lookup_failed" });
    }
    if (!tugas) return json(404, { error: "Tugas tidak ditemukan", code: "not_found" });
    if (tugas.status_publikasi !== "published") {
      return json(403, { error: "Tugas belum dipublikasikan", code: "not_published" });
    }
    if (siswa.kelas_id !== tugas.kelas_id) {
      return json(403, { error: "Tugas tidak untuk kelas siswa ini", code: "wrong_class" });
    }

    const { error: upsertErr } = await client.from("status_tugas_siswa").upsert(
      {
        tugas_id: tugasId,
        siswa_id: siswaId,
        status,
        selesai_pada: status === "selesai" ? new Date().toISOString() : null,
      },
      { onConflict: "tugas_id,siswa_id" },
    );

    if (upsertErr) {
      console.error("update-student-task-status: upsert gagal", upsertErr.code);
      return json(500, { error: "Gagal menyimpan status.", code: "upsert_failed" });
    }

    return json(200, { success: true, status });
  } catch (e) {
    console.error("update-student-task-status: unexpected", e instanceof Error ? e.message : String(e));
    return json(500, { error: "Terjadi kesalahan internal pada server.", code: "internal_error" });
  }
});
