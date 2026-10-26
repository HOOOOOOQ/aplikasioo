// supabase/functions/student-access/index.ts
//
// Validasi kode akses siswa dan terbitkan TOKEN bertanda tangan (HMAC-SHA256).
//
// Perbaikan keamanan:
// - Versi lama memakai token base64(siswa_id:timestamp) yang bisa DIPALSUKAN siapa pun
//   yang tahu siswa_id (dan siswa_id bisa dibaca lewat anon key).
// - Sekarang: token = "<siswa_id>.<exp_epoch>.<hmac>" dan diverifikasi oleh
//   update-student-task-status. Tanpa secret server, token tidak bisa dibuat.
//
// Secret: STUDENT_TOKEN_SECRET (disarankan) atau fallback SUPABASE_SERVICE_ROLE_KEY.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 180; // 180 hari (1 semester)

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

export async function signToken(siswaId: string, secret: string, exp: number): Promise<string> {
  const payload = `${siswaId}.${exp}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  return `${payload}.${base64url(new Uint8Array(sig))}`;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed. Gunakan POST.", code: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY") ?? "";
  const tokenSecret = Deno.env.get("STUDENT_TOKEN_SECRET") ?? serviceRoleKey;

  if (!supabaseUrl || !serviceRoleKey || !tokenSecret) {
    console.error("student-access: secret server belum lengkap");
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

    const kode = String((parsed as Record<string, unknown>).kode_akses ?? "").trim();
    if (!kode) return json(400, { error: "kode_akses wajib diisi", code: "missing_code" });
    if (kode.length > 64) return json(400, { error: "kode_akses tidak valid", code: "invalid_code" });

    const client = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: siswa, error } = await client
      .from("siswa")
      .select("id, nama, kelas_id, status_aktif, kelas(nama_kelas)")
      .eq("kode_akses", kode)
      .eq("status_aktif", true)
      .maybeSingle();

    if (error) {
      console.error("student-access: query gagal", error.code);
      return json(500, { error: "Gagal memverifikasi kode.", code: "lookup_failed" });
    }
    if (!siswa) {
      return json(404, { error: "Kode tidak ditemukan atau siswa tidak aktif", code: "not_found" });
    }

    const exp = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
    const token = await signToken(siswa.id, tokenSecret, exp);
    const kelas = siswa.kelas as unknown;
    const kelasNama = kelas && typeof kelas === "object" && !Array.isArray(kelas)
      ? (kelas as Record<string, unknown>).nama_kelas ?? null
      : null;

    return json(200, {
      success: true,
      siswa: {
        id: siswa.id,
        nama: siswa.nama,
        kelas_id: siswa.kelas_id,
        kelas_nama: kelasNama,
      },
      token,
      exp,
    });
  } catch (e) {
    console.error("student-access: unexpected", e instanceof Error ? e.message : String(e));
    return json(500, { error: "Terjadi kesalahan internal pada server.", code: "internal_error" });
  }
});
