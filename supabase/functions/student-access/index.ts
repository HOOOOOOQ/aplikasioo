// supabase/functions/student-access/index.ts
//
// Verifikasi kode akses siswa DI SERVER, lalu terbitkan token bertanda tangan
// HMAC-SHA256. Mendukung dua mode kode:
//
//   1. Kode per-siswa  (kode_akses_siswa.siswa_id terisi)
//      → kode rahasia menunjuk tepat satu siswa. Langsung terbit token.
//   2. Kode kelas      (kode_akses_siswa.kelas_id terisi, siswa_id null)
//      → langkah 1 mengembalikan `claim_token` singkat (15 menit).
//        langkah 2 (`claim_token` + `siswa_id`) memvalidasi siswa berada di
//        kelas tersebut, mengklaim kode secara atomik, lalu menerbitkan token.
//
// Backward compatibility: kode lama di `public.siswa.kode_akses` (plaintext)
// masih diterima, ditandai `legacy: true`.
//
// Keamanan:
//  * Kode tidak pernah dicatat ke log.
//  * Rate limit: maksimum 10 kegagalan / 10 menit per IP.
//  * Klaim memakai RPC `claim_kode_akses` (SELECT ... FOR UPDATE) agar dua
//    pengguna tidak bisa memakai kode sekali-pakai secara bersamaan.
//  * Token akses: "<siswa_id>.<exp>.<hmac>" — diverifikasi oleh
//    update-student-task-status. Tanpa secret server, token tidak bisa dipalsukan.
//
// Secret: STUDENT_TOKEN_SECRET (disarankan) atau fallback SUPABASE_SERVICE_ROLE_KEY.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ACCESS_TOKEN_TTL = 60 * 60 * 24 * 180; // 180 hari
const CLAIM_TOKEN_TTL = 60 * 15; // 15 menit untuk memilih nama di kode kelas
const RATE_LIMIT_WINDOW_MINUTES = 10;
const RATE_LIMIT_MAX_FAILURES = 10;

interface JsonMap {
  [key: string]: unknown;
}

function json(status: number, payload: JsonMap): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Error "objek database belum ada" (migration 004/005 belum dijalankan) atau
 * schema cache basi. Dibedakan dari gangguan server supaya pengguna mendapat
 * pesan yang bisa ditindaklanjuti, bukan "Gagal memverifikasi kode".
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

function schemaNotReadyResponse(): Response {
  return json(503, {
    error:
      "Skema kode akses belum tersedia di database. Hubungi admin sekolah " +
      "(migration 005_access_codes_schema_repair.sql belum dijalankan).",
    code: "schema_not_ready",
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

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Normalisasi kode: huruf besar, tanpa spasi/tanda hubung. */
function normalizeCode(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function signAccessToken(siswaId: string, exp: number, secret: string): Promise<string> {
  const payload = `${siswaId}.${exp}`;
  return `${payload}.${await hmac(payload, secret)}`;
}

async function signClaimToken(kodeId: string, exp: number, secret: string): Promise<string> {
  const payload = `claim.${kodeId}.${exp}`;
  return `${payload}.${await hmac(payload, secret)}`;
}

async function verifyClaimToken(token: string, secret: string): Promise<{ kodeId: string; exp: number } | null> {
  const parts = token.split(".");
  if (parts.length !== 4 || parts[0] !== "claim") return null;
  const kodeId = parts[1];
  const exp = Number(parts[2]);
  const sig = parts[3];
  if (!kodeId || !Number.isFinite(exp) || !sig) return null;
  const expected = await hmac(`claim.${kodeId}.${exp}`, secret);
  if (!safeEqual(sig, expected)) return null;
  if (exp * 1000 < Date.now()) return null;
  return { kodeId, exp };
}

function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  const first = fwd.split(",")[0].trim();
  return first || req.headers.get("cf-connecting-ip") || "unknown";
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed. Gunakan POST.", code: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY") ?? "";
  const tokenSecret = Deno.env.get("STUDENT_TOKEN_SECRET") ?? serviceRoleKey;

  if (!supabaseUrl || !serviceRoleKey || !tokenSecret) {
    console.error("student-access: secret server belum lengkap");
    return json(500, { error: "Server misconfigured.", code: "server_misconfigured" });
  }

  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const ip = clientIp(req);
  const nowSec = Math.floor(Date.now() / 1000);

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
    const body = parsed as JsonMap;

    // ---------- Rate limit ----------
    const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60_000).toISOString();
    const { count: failures, error: limitErr } = await client
      .from("kode_akses_attempt")
      .select("id", { count: "exact", head: true })
      .eq("ip", ip)
      .eq("success", false)
      .gte("created_at", windowStart);

    if (limitErr) {
      console.error("student-access: rate limit tidak tersedia", limitErr.code);
      if (isSchemaMissing(limitErr)) return schemaNotReadyResponse();
      // Rate limit gagal karena sebab lain: jangan blokir verifikasi kode,
      // tetapi catat agar terlihat di log server.
    }

    if ((failures ?? 0) >= RATE_LIMIT_MAX_FAILURES) {
      return json(429, {
        error: "Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.",
        code: "too_many_attempts",
      });
    }

    const recordAttempt = async (success: boolean) => {
      try {
        const { error } = await client.from("kode_akses_attempt").insert({ ip, success });
        if (error) console.warn("student-access: gagal mencatat percobaan", error.code);
      } catch (_) {
        // pencatatan rate limit tidak boleh menggagalkan permintaan
      }
    };

    // ---------- Langkah 2: klaim kode kelas ----------
    const claimTokenRaw = String(body.claim_token ?? "").trim();
    if (claimTokenRaw) {
      const claim = await verifyClaimToken(claimTokenRaw, tokenSecret);
      if (!claim) {
        await recordAttempt(false);
        return json(401, {
          error: "Sesi kode sudah kedaluwarsa. Masukkan kode kembali.",
          code: "invalid_claim_token",
        });
      }
      const siswaId = String(body.siswa_id ?? "").trim();
      if (!siswaId) {
        return json(400, { error: "siswa_id wajib diisi.", code: "missing_fields" });
      }

      const { data: kodeRow, error: kodeErr } = await client
        .from("kode_akses_siswa")
        .select("id, kode_hash, kelas_id, siswa_id, single_use, status")
        .eq("id", claim.kodeId)
        .maybeSingle();

      if (kodeErr) {
        console.error("student-access: lookup kode kelas gagal", kodeErr.code);
        if (isSchemaMissing(kodeErr)) return schemaNotReadyResponse();
        return json(500, { error: "Gagal memverifikasi kode.", code: "lookup_failed" });
      }
      if (!kodeRow) {
        return json(404, { error: "Kode tidak ditemukan.", code: "kode_not_found" });
      }

      const { data: claimResult, error: claimErr } = await client.rpc("claim_kode_akses", {
        p_kode_hash: kodeRow.kode_hash,
        p_siswa_id: siswaId,
      });
      if (claimErr) {
        console.error("student-access: claim gagal", claimErr.code);
        if (isSchemaMissing(claimErr)) return schemaNotReadyResponse();
        return json(500, { error: "Gagal memverifikasi kode.", code: "claim_failed" });
      }
      const result = (claimResult ?? {}) as JsonMap;
      if (result.ok !== true) {
        await recordAttempt(false);
        return codeErrorResponse(String(result.reason ?? "not_found"));
      }

      const { data: siswa, error: siswaErr } = await client
        .from("siswa")
        .select("id, nama, kelas_id, status_aktif, kelas(nama_kelas)")
        .eq("id", siswaId)
        .maybeSingle();

      if (siswaErr || !siswa || siswa.status_aktif !== true) {
        return json(404, { error: "Data siswa tidak ditemukan atau tidak aktif.", code: "student_not_found" });
      }

      await recordAttempt(true);
      const exp = nowSec + ACCESS_TOKEN_TTL;
      const token = await signAccessToken(siswa.id as string, exp, tokenSecret);
      const kelas = siswa.kelas as unknown;
      const kelasNama = kelas && typeof kelas === "object" && !Array.isArray(kelas)
        ? ((kelas as JsonMap).nama_kelas ?? null)
        : null;

      return json(200, {
        success: true,
        mode: "kelas",
        siswa: {
          id: siswa.id,
          nama: siswa.nama,
          kelas_id: siswa.kelas_id,
          kelas_nama: kelasNama,
        },
        token,
        exp,
      });
    }

    // ---------- Langkah 1: verifikasi kode ----------
    const rawCode = String(body.kode_akses ?? "").trim();
    if (!rawCode) {
      return json(400, { error: "kode_akses wajib diisi", code: "missing_code" });
    }
    if (rawCode.length > 64) {
      await recordAttempt(false);
      return json(400, { error: "Format kode tidak valid.", code: "invalid_code" });
    }

    const normalized = normalizeCode(rawCode);
    if (normalized.length < 6) {
      await recordAttempt(false);
      return json(404, { error: "Kode tidak ditemukan.", code: "kode_not_found" });
    }

    const kodeHash = await sha256Hex(normalized);
    const { data: kodeRow, error: kodeLookupErr } = await client
      .from("kode_akses_siswa")
      .select("id, kelas_id, siswa_id, single_use, status, expires_at, used_at")
      .eq("kode_hash", kodeHash)
      .maybeSingle();

    if (kodeLookupErr) {
      console.error("student-access: lookup kode gagal", kodeLookupErr.code);
      if (isSchemaMissing(kodeLookupErr)) return schemaNotReadyResponse();
      return json(500, { error: "Gagal memverifikasi kode.", code: "lookup_failed" });
    }

    if (kodeRow) {
      if (kodeRow.status === "revoked") {
        await recordAttempt(false);
        return codeErrorResponse("revoked");
      }
      if (kodeRow.status === "used" && kodeRow.single_use === true) {
        await recordAttempt(false);
        return codeErrorResponse("used");
      }
      if (kodeRow.expires_at && new Date(kodeRow.expires_at as string).getTime() <= Date.now()) {
        await client.from("kode_akses_siswa").update({ status: "expired" }).eq("id", kodeRow.id);
        await recordAttempt(false);
        return codeErrorResponse("expired");
      }

      // Kode per-siswa: langsung klaim.
      if (kodeRow.siswa_id) {
        const { data: claimResult, error: claimErr } = await client.rpc("claim_kode_akses", {
          p_kode_hash: kodeHash,
          p_siswa_id: kodeRow.siswa_id,
        });
        if (claimErr) {
          console.error("student-access: claim gagal", claimErr.code);
          if (isSchemaMissing(claimErr)) return schemaNotReadyResponse();
          return json(500, { error: "Gagal memverifikasi kode.", code: "claim_failed" });
        }
        const result = (claimResult ?? {}) as JsonMap;
        if (result.ok !== true) {
          await recordAttempt(false);
          return codeErrorResponse(String(result.reason ?? "not_found"));
        }

        const { data: siswa } = await client
          .from("siswa")
          .select("id, nama, kelas_id, status_aktif, kelas(nama_kelas)")
          .eq("id", kodeRow.siswa_id)
          .maybeSingle();

        if (!siswa || siswa.status_aktif !== true) {
          return json(404, { error: "Siswa tidak ditemukan atau tidak aktif.", code: "student_not_found" });
        }

        await recordAttempt(true);
        const exp = nowSec + ACCESS_TOKEN_TTL;
        const token = await signAccessToken(siswa.id as string, exp, tokenSecret);
        const kelas = siswa.kelas as unknown;
        const kelasNama = kelas && typeof kelas === "object" && !Array.isArray(kelas)
          ? ((kelas as JsonMap).nama_kelas ?? null)
          : null;

        return json(200, {
          success: true,
          mode: "siswa",
          siswa: {
            id: siswa.id,
            nama: siswa.nama,
            kelas_id: siswa.kelas_id,
            kelas_nama: kelasNama,
          },
          token,
          exp,
        });
      }

      // Kode kelas: minta siswa memilih namanya.
      const { data: kelas } = await client
        .from("kelas")
        .select("id, nama_kelas")
        .eq("id", kodeRow.kelas_id)
        .maybeSingle();

      await recordAttempt(true);
      const claimExp = nowSec + CLAIM_TOKEN_TTL;
      const claimToken = await signClaimToken(String(kodeRow.id), claimExp, tokenSecret);

      return json(200, {
        success: true,
        mode: "kelas",
        kelas: {
          id: kodeRow.kelas_id,
          nama: kelas?.nama_kelas ?? null,
        },
        claim_token: claimToken,
        exp: claimExp,
      });
    }

    // ---------- Fallback: kode legacy di tabel siswa ----------
    const { data: legacySiswa, error: legacyErr } = await client
      .from("siswa")
      .select("id, nama, kelas_id, status_aktif, kelas(nama_kelas)")
      .eq("kode_akses", rawCode)
      .eq("status_aktif", true)
      .maybeSingle();

    if (legacyErr) {
      console.error("student-access: lookup legacy gagal", legacyErr.code);
      if (isSchemaMissing(legacyErr)) return schemaNotReadyResponse();
      return json(500, { error: "Gagal memverifikasi kode.", code: "lookup_failed" });
    }
    if (!legacySiswa) {
      await recordAttempt(false);
      return codeErrorResponse("not_found");
    }

    await recordAttempt(true);
    const exp = nowSec + ACCESS_TOKEN_TTL;
    const token = await signAccessToken(legacySiswa.id as string, exp, tokenSecret);
    const kelas = legacySiswa.kelas as unknown;
    const kelasNama = kelas && typeof kelas === "object" && !Array.isArray(kelas)
      ? ((kelas as JsonMap).nama_kelas ?? null)
      : null;

    return json(200, {
      success: true,
      mode: "siswa",
      legacy: true,
      siswa: {
        id: legacySiswa.id,
        nama: legacySiswa.nama,
        kelas_id: legacySiswa.kelas_id,
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

function codeErrorResponse(reason: string): Response {
  switch (reason) {
    case "expired":
      return json(410, {
        error: "Kode sudah kedaluwarsa. Minta kode baru ke admin atau guru.",
        code: "expired",
      });
    case "revoked":
      return json(403, {
        error: "Kode sudah dicabut. Hubungi admin atau guru.",
        code: "revoked",
      });
    case "used":
      return json(409, {
        error: "Kode sudah digunakan. Minta kode baru ke admin atau guru.",
        code: "used",
      });
    case "wrong_student":
      return json(403, {
        error: "Kode ini bukan untuk akun siswa tersebut.",
        code: "wrong_student",
      });
    case "class_mismatch":
      return json(403, {
        error: "Siswa tidak terdaftar di kelas untuk kode ini.",
        code: "class_mismatch",
      });
    default:
      return json(404, {
        error: "Kode tidak ditemukan. Periksa kembali penulisannya.",
        code: "kode_not_found",
      });
  }
}
