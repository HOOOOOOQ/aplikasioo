// supabase/functions/student-portal/index.ts
//
// Endpoint siswa (tanpa login) untuk fitur akademik ronde 4:
//   * submit_task  → kumpulkan jawaban tugas (dengan revisi berurutan)
//   * my_submissions → daftar pengumpulan milik siswa + nilai/umpan balik
//   * add_comment  → komentar pada diskusi tugas
//   * list_comments → daftar komentar diskusi tugas
//   * notifications → pusat notifikasi siswa
//   * read_notification → tandai notifikasi dibaca
//
// Keamanan:
//   * WAJIB token HMAC dari student-access ("<siswa_id>.<exp>.<hmac>").
//   * siswa_id diambil dari token, BUKAN dari body (client tidak bisa memilih
//     identitas siswa lain).
//   * service_role hanya ada di server.
//   * Tugas harus published dan kelasnya sama dengan kelas siswa.
//
// Secret: STUDENT_TOKEN_SECRET (disarankan) atau fallback SUPABASE_SERVICE_ROLE_KEY.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonMap = Record<string, unknown>;

function json(status: number, payload: JsonMap): Response {
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

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Token siswa: "<siswa_id>.<exp>.<signature>". */
async function verifyStudentToken(
  token: string,
  secret: string,
): Promise<{ siswaId: string } | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [siswaId, expRaw, signature] = parts;
  const exp = Number(expRaw);
  if (!siswaId || !Number.isFinite(exp)) return null;
  if (exp * 1000 < Date.now()) return null;
  const expected = await hmac(`${siswaId}.${expRaw}`, secret);
  if (!safeEqual(expected, signature)) return null;
  return { siswaId };
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v: unknown) => typeof v === "string" && UUID_RE.test(v.trim());

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
    console.error("student-portal: konfigurasi server belum lengkap");
    return json(500, { error: "Server misconfigured.", code: "server_misconfigured" });
  }

  let body: JsonMap = {};
  try {
    const parsed = await req.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json(400, { error: "Body harus objek JSON.", code: "invalid_json" });
    }
    body = parsed as JsonMap;
  } catch {
    return json(400, { error: "Body harus JSON yang valid.", code: "invalid_json" });
  }

  const token = String(body.token ?? "").trim();
  if (!token) {
    return json(401, {
      error: "Token identitas siswa wajib. Verifikasi kode akses di aplikasi.",
      code: "student_token_missing",
    });
  }
  const identity = await verifyStudentToken(token, tokenSecret);
  if (!identity) {
    return json(401, {
      error: "Token identitas siswa tidak valid atau kedaluwarsa. Verifikasi ulang kode akses.",
      code: "student_token_invalid",
    });
  }
  const siswaId = identity.siswaId;

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const action = String(body.action ?? "").trim();

  try {
    // ---------- Ambil identitas siswa (kelas & nama) sekali ----------
    const { data: siswa, error: siswaErr } = await admin
      .from("siswa")
      .select("id, nama, kelas_id, status_aktif")
      .eq("id", siswaId)
      .maybeSingle();

    if (siswaErr) {
      console.error("student-portal: gagal membaca siswa", siswaErr.code);
      return json(500, { error: "Gagal membaca data siswa.", code: "lookup_failed" });
    }
    if (!siswa || siswa.status_aktif !== true) {
      return json(404, { error: "Siswa tidak ditemukan atau tidak aktif.", code: "student_not_found" });
    }

    // ---------- Kumpulkan tugas ----------
    if (action === "submit_task") {
      const tugasId = String(body.tugas_id ?? "").trim();
      const jawaban = String(body.jawaban_teks ?? "").trim();
      if (!isUuid(tugasId)) {
        return json(400, { error: "tugas_id tidak valid.", code: "invalid_tugas" });
      }
      if (jawaban.length < 1) {
        return json(400, { error: "Jawaban masih kosong.", code: "empty_answer" });
      }
      if (jawaban.length > 8000) {
        return json(400, { error: "Jawaban terlalu panjang (maks. 8000 karakter).", code: "answer_too_long" });
      }

      const { data: tugas, error: tugasErr } = await admin
        .from("tugas")
        .select("id, kelas_id, status_publikasi, tenggat_waktu")
        .eq("id", tugasId)
        .maybeSingle();
      if (tugasErr) {
        console.error("student-portal: gagal membaca tugas", tugasErr.code);
        return json(500, { error: "Gagal membaca tugas.", code: "lookup_failed" });
      }
      if (!tugas) {
        return json(404, { error: "Tugas tidak ditemukan.", code: "tugas_not_found" });
      }
      if (tugas.status_publikasi !== "published") {
        return json(403, { error: "Tugas belum dipublikasikan.", code: "not_published" });
      }
      if (!siswa.kelas_id || tugas.kelas_id !== siswa.kelas_id) {
        return json(403, { error: "Tugas ini bukan untuk kelas Anda.", code: "wrong_class" });
      }

      // Revisi berikutnya dihitung di server (client tidak boleh menentukan).
      const { data: last } = await admin
        .from("tugas_pengumpulan")
        .select("revisi_ke")
        .eq("tugas_id", tugasId)
        .eq("siswa_id", siswaId)
        .order("revisi_ke", { ascending: false })
        .limit(1)
        .maybeSingle();

      const nextRevisi = (last?.revisi_ke ?? 0) + 1;
      if (nextRevisi > 20) {
        return json(409, {
          error: "Batas 20 revisi tercapai. Hubungi guru Anda.",
          code: "revision_limit",
        });
      }

      const { data: inserted, error: insertErr } = await admin
        .from("tugas_pengumpulan")
        .insert({
          tugas_id: tugasId,
          siswa_id: siswaId,
          revisi_ke: nextRevisi,
          jawaban_teks: jawaban,
          status: "terkirim",
          submitted_at: new Date().toISOString(),
        })
        .select("id, revisi_ke, status, submitted_at")
        .single();

      if (insertErr) {
        console.error("student-portal: insert pengumpulan gagal", insertErr.code);
        if (insertErr.code === "23505") {
          return json(409, { error: "Pengumpulan bentrok, coba kirim ulang.", code: "conflict" });
        }
        return json(500, { error: "Gagal menyimpan jawaban.", code: "insert_failed" });
      }

      await admin.from("notifikasi").insert({
        profile_id: (await admin
          .from("tugas")
          .select("guru_id")
          .eq("id", tugasId)
          .maybeSingle()).data?.guru_id ?? null,
        tipe: "tugas",
        judul: `Pengumpulan baru: ${siswa.nama}`,
        isi: `Revisi ke-${nextRevisi}`,
        ref_id: tugasId,
      });

      return json(200, { success: true, data: inserted, revisi_ke: nextRevisi });
    }

    // ---------- Riwayat pengumpulan milik siswa ----------
    if (action === "my_submissions") {
      const tugasIdRaw = body.tugas_id;
      let query = admin
        .from("tugas_pengumpulan")
        .select("id, tugas_id, revisi_ke, jawaban_teks, status, nilai, umpan_balik, submitted_at, reviewed_at")
        .eq("siswa_id", siswaId)
        .order("submitted_at", { ascending: false })
        .limit(50);
      if (isUuid(tugasIdRaw)) query = query.eq("tugas_id", String(tugasIdRaw).trim());

      const { data, error } = await query;
      if (error) {
        console.error("student-portal: gagal membaca pengumpulan", error.code);
        return json(500, { error: "Gagal membaca pengumpulan.", code: "lookup_failed" });
      }
      return json(200, { success: true, data: data ?? [] });
    }

    // ---------- Diskusi tugas ----------
    if (action === "list_comments") {
      const tugasId = String(body.tugas_id ?? "").trim();
      if (!isUuid(tugasId)) {
        return json(400, { error: "tugas_id tidak valid.", code: "invalid_tugas" });
      }
      const { data: tugas } = await admin
        .from("tugas")
        .select("id, kelas_id, status_publikasi")
        .eq("id", tugasId)
        .maybeSingle();
      if (!tugas) return json(404, { error: "Tugas tidak ditemukan.", code: "tugas_not_found" });
      if (tugas.status_publikasi !== "published") {
        return json(403, { error: "Tugas belum dipublikasikan.", code: "not_published" });
      }
      if (!siswa.kelas_id || tugas.kelas_id !== siswa.kelas_id) {
        return json(403, { error: "Diskusi ini bukan untuk kelas Anda.", code: "wrong_class" });
      }
      const { data, error } = await admin
        .from("tugas_komentar")
        .select("id, author_role, author_nama, isi, created_at")
        .eq("tugas_id", tugasId)
        .order("created_at", { ascending: true })
        .limit(200);
      if (error) {
        console.error("student-portal: gagal membaca komentar", error.code);
        return json(500, { error: "Gagal membaca diskusi.", code: "lookup_failed" });
      }
      return json(200, { success: true, data: data ?? [] });
    }

    if (action === "add_comment") {
      const tugasId = String(body.tugas_id ?? "").trim();
      const isi = String(body.isi ?? "").trim();
      if (!isUuid(tugasId)) {
        return json(400, { error: "tugas_id tidak valid.", code: "invalid_tugas" });
      }
      if (isi.length < 1) return json(400, { error: "Komentar kosong.", code: "empty_comment" });
      if (isi.length > 1500) {
        return json(400, { error: "Komentar terlalu panjang (maks. 1500 karakter).", code: "comment_too_long" });
      }
      const { data: tugas } = await admin
        .from("tugas")
        .select("id, kelas_id, status_publikasi")
        .eq("id", tugasId)
        .maybeSingle();
      if (!tugas) return json(404, { error: "Tugas tidak ditemukan.", code: "tugas_not_found" });
      if (tugas.status_publikasi !== "published") {
        return json(403, { error: "Tugas belum dipublikasikan.", code: "not_published" });
      }
      if (!siswa.kelas_id || tugas.kelas_id !== siswa.kelas_id) {
        return json(403, { error: "Diskusi ini bukan untuk kelas Anda.", code: "wrong_class" });
      }

      const { data, error } = await admin
        .from("tugas_komentar")
        .insert({
          tugas_id: tugasId,
          author_role: "siswa",
          author_siswa_id: siswaId,
          author_nama: siswa.nama,
          isi,
        })
        .select("id, author_role, author_nama, isi, created_at")
        .single();
      if (error) {
        console.error("student-portal: gagal menyimpan komentar", error.code);
        return json(500, { error: "Gagal mengirim komentar.", code: "insert_failed" });
      }
      return json(200, { success: true, data });
    }

    // ---------- Notifikasi siswa ----------
    if (action === "notifications") {
      const { data, error } = await admin
        .from("notifikasi")
        .select("id, tipe, judul, isi, ref_id, is_read, created_at")
        .eq("siswa_id", siswaId)
        .order("created_at", { ascending: false })
        .limit(50);
      if (error) {
        console.error("student-portal: gagal membaca notifikasi", error.code);
        return json(500, { error: "Gagal membaca notifikasi.", code: "lookup_failed" });
      }
      return json(200, { success: true, data: data ?? [] });
    }

    if (action === "read_notification") {
      const id = String(body.id ?? "").trim();
      if (!isUuid(id)) return json(400, { error: "id tidak valid.", code: "invalid_id" });
      const { error } = await admin
        .from("notifikasi")
        .update({ is_read: true })
        .eq("id", id)
        .eq("siswa_id", siswaId);
      if (error) {
        console.error("student-portal: gagal menandai notifikasi", error.code);
        return json(500, { error: "Gagal menandai notifikasi.", code: "update_failed" });
      }
      return json(200, { success: true });
    }

    if (action === "read_all_notifications") {
      const { error } = await admin
        .from("notifikasi")
        .update({ is_read: true })
        .eq("siswa_id", siswaId)
        .eq("is_read", false);
      if (error) {
        console.error("student-portal: gagal menandai semua notifikasi", error.code);
        return json(500, { error: "Gagal menandai notifikasi.", code: "update_failed" });
      }
      return json(200, { success: true });
    }

    return json(400, {
      error: "action tidak dikenal. Gunakan submit_task, my_submissions, list_comments, add_comment, notifications.",
      code: "invalid_action",
    });
  } catch (e) {
    console.error("student-portal: unexpected", e instanceof Error ? e.message : String(e));
    return json(500, { error: "Terjadi kesalahan internal pada server.", code: "internal_error" });
  }
});
