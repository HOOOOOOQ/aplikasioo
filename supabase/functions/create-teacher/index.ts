// supabase/functions/create-teacher/index.ts
//
// Edge Function: membuat akun guru (auth.users + public.profiles) hanya oleh admin aktif.
//
// Alur keamanan:
//   1. Ambil bearer token dari header Authorization (token sesi admin yang login di aplikasi).
//   2. Verifikasi token tersebut ke Supabase Auth (GoTrue) memakai service_role client.
//      Identitas TIDAK PERNAH diambil dari body/parameter yang dikirim client.
//   3. Baca role dari tabel profiles memakai service_role (sumber tepercaya, bypass RLS).
//   4. Baru buat user memakai Auth Admin API (service_role tetap hanya di server).
//
// Deploy:
//   supabase functions deploy create-teacher
//   (verify_jwt = true diatur di supabase/config.toml — pertahanan berlapis)
//
// Secret yang dibutuhkan (otomatis tersedia di project Supabase; jangan di-hardcode):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   (fallback SERVICE_ROLE_KEY untuk project lama yang memakai nama secret tersebut)

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

/** Ambil token mentah dari "Authorization: Bearer <jwt>". */
function extractBearerToken(headerValue: string | null): string {
  if (!headerValue) return "";
  const value = headerValue.trim();
  const match = /^Bearer\s+(.+)$/i.exec(value);
  return (match ? match[1] : value).trim();
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed. Gunakan POST.", code: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY") ?? "";

  if (!supabaseUrl || !serviceRoleKey) {
    // Jangan bocorkan nilai secret apa pun ke client.
    console.error("create-teacher: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY belum tersedia");
    return json(500, {
      error: "Server misconfigured: secret SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY wajib tersedia.",
      code: "server_misconfigured",
    });
  }

  const token = extractBearerToken(req.headers.get("Authorization"));
  if (!token) {
    return json(401, {
      error: "Unauthorized: header Authorization (Bearer token admin) tidak dikirim.",
      code: "missing_token",
    });
  }

  try {
    // Service-role client HANYA dipakai di server. Tidak pernah dikirim ke aplikasi.
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 1) Verifikasi token admin. Ini memvalidasi signature + masa berlaku JWT
    //    ke GoTrue, sehingga token palsu/kedaluwarsa ditolak di sini.
    const {
      data: { user },
      error: userErr,
    } = await admin.auth.getUser(token);

    if (userErr || !user) {
      const errMsg = (userErr?.message ?? "").toLowerCase();
      // Log hanya metadata aman (pesan error), tanpa token/credential.
      console.warn("create-teacher: verifikasi token gagal:", userErr?.message ?? "user null");

      // Ini BUKAN kesalahan admin: service_role key tidak cocok dengan SUPABASE_URL
      // (mis. secret diambil dari project lain). Balas 500, bukan 401.
      if (errMsg.includes("api key") || errMsg.includes("apikey")) {
        console.error("create-teacher: service role key tidak cocok dengan project URL");
        return json(500, {
          error:
            "Server misconfigured: SUPABASE_SERVICE_ROLE_KEY tidak cocok dengan SUPABASE_URL project ini.",
          code: "server_misconfigured",
        });
      }

      return json(401, {
        error: "Unauthorized: token admin tidak valid atau sudah kedaluwarsa.",
        code: "invalid_token",
        detail: userErr?.message ?? null,
      });
    }

    // 2) Otorisasi role dari database (bukan dari klaim client).
    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("role, is_active")
      .eq("id", user.id)
      .maybeSingle();

    if (profileErr) {
      console.error("create-teacher: gagal membaca profiles:", profileErr.code);
      return json(500, {
        error: "Gagal memverifikasi profil admin.",
        code: "profile_lookup_failed",
      });
    }

    if (!profile || profile.role !== "admin" || profile.is_active !== true) {
      return json(403, {
        error: "Forbidden: hanya admin aktif yang boleh membuat akun guru.",
        code: "not_admin",
      });
    }

    // 3) Validasi input.
    let parsed: unknown;
    try {
      parsed = await req.json();
    } catch (_) {
      return json(400, { error: "Body harus JSON yang valid.", code: "invalid_json" });
    }

    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return json(400, { error: "Body harus berupa objek JSON.", code: "invalid_json" });
    }

    const body = parsed as Record<string, unknown>;
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const password = typeof body.password === "string" ? body.password : "";
    const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";

    if (!email || !password || !fullName) {
      return json(400, {
        error: "email, password, dan full_name wajib diisi.",
        code: "missing_fields",
      });
    }
    if (email.length > 254 || !EMAIL_PATTERN.test(email)) {
      return json(400, { error: "Format email tidak valid.", code: "invalid_email" });
    }
    if (password.length < 6) {
      return json(400, {
        error: "Password minimal 6 karakter.",
        code: "weak_password",
      });
    }
    if (fullName.length < 2 || fullName.length > 100) {
      return json(400, {
        error: "Nama lengkap harus 2-100 karakter.",
        code: "invalid_full_name",
      });
    }

    // 4) Cegah duplikasi sebelum memanggil Auth Admin API.
    const { data: existingProfiles, error: existingErr } = await admin
      .from("profiles")
      .select("id")
      .eq("email", email)
      .limit(1);

    if (existingErr) {
      console.error("create-teacher: gagal cek duplikat email:", existingErr.code);
      return json(500, {
        error: "Gagal memeriksa duplikasi email.",
        code: "duplicate_check_failed",
      });
    }
    if (existingProfiles && existingProfiles.length > 0) {
      return json(409, {
        error: "Email sudah terdaftar sebagai pengguna.",
        code: "email_exists",
      });
    }

    // 5) Buat user di Auth.
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });

    if (createErr || !created?.user) {
      const message = createErr?.message ?? "Gagal membuat user";
      const lowerMessage = message.toLowerCase();

      // Service role key yang salah/tidak berhak tidak boleh terlihat seperti input salah.
      if (
        createErr?.status === 403 ||
        lowerMessage.includes("permission") ||
        lowerMessage.includes("service_role") ||
        lowerMessage.includes("not allowed")
      ) {
        console.error("create-teacher: Auth Admin API menolak service role key");
        return json(500, {
          error:
            "Server tidak berhak membuat user. Periksa SUPABASE_SERVICE_ROLE_KEY (harus service_role project ini).",
          code: "server_misconfigured",
        });
      }

      const duplicated = /already|registered|exists/i.test(message);
      return json(duplicated ? 409 : 400, {
        error: message,
        code: duplicated ? "email_exists" : "create_user_failed",
      });
    }

    // 6) Simpan profil guru. Jika gagal, rollback user agar tidak ada akun orphan.
    const { error: insertErr } = await admin.from("profiles").insert({
      id: created.user.id,
      full_name: fullName,
      email,
      role: "guru",
      is_active: true,
    });

    if (insertErr) {
      console.error("create-teacher: gagal insert profiles:", insertErr.code);
      await admin.auth.admin.deleteUser(created.user.id);
      return json(500, {
        error: "Gagal menyimpan profil guru. Akun auth dibatalkan (rollback).",
        code: "profile_insert_failed",
      });
    }

    return json(200, {
      success: true,
      user_id: created.user.id,
      email,
      role: "guru",
    });
  } catch (e) {
    // Error tak terduga: jangan kirim detail internal/credential ke client.
    console.error("create-teacher: unexpected error:", e instanceof Error ? e.message : String(e));
    return json(500, {
      error: "Terjadi kesalahan internal pada server.",
      code: "internal_error",
    });
  }
});
