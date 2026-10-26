// supabase/functions/student-chat/index.ts
//
// Chat untuk SISWA (tanpa login), memakai token identitas HMAC dari
// student-access. Guru/admin memakai client Supabase langsung (RLS), bukan
// endpoint ini.
//
// Aksi:
//   threads        → daftar percakapan yang diikuti siswa + unread
//   messages       → riwayat pesan (pagination dengan `before`)
//   send           → kirim pesan
//   mark_read      → tandai percakapan sudah dibaca
//   open_thread    → buka/buat percakapan privat dengan guru atau grup kelas
//
// Keamanan:
//   * siswa_id dari token, bukan body.
//   * Anggota thread diverifikasi dari tabel chat_members (service_role),
//     sehingga siswa tidak bisa membaca percakapan orang lain.
//   * Body dibatasi 2000 karakter; client_id dipakai untuk deduplikasi.
//   * service_role hanya di server.

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

async function verifyStudentToken(token: string, secret: string): Promise<{ siswaId: string } | null> {
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
    console.error("student-chat: konfigurasi server belum lengkap");
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
      error: "Token identitas siswa tidak valid atau kedaluwarsa.",
      code: "student_token_invalid",
    });
  }
  const siswaId = identity.siswaId;

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const action = String(body.action ?? "").trim();

  try {
    const { data: siswa } = await admin
      .from("siswa")
      .select("id, nama, kelas_id, status_aktif")
      .eq("id", siswaId)
      .maybeSingle();

    if (!siswa || siswa.status_aktif !== true) {
      return json(404, { error: "Siswa tidak ditemukan atau tidak aktif.", code: "student_not_found" });
    }

    // Pastikan siswa menjadi anggota thread; kalau tidak → 403.
    const requireMember = async (threadId: string): Promise<boolean> => {
      const { data: member } = await admin
        .from("chat_members")
        .select("id")
        .eq("thread_id", threadId)
        .eq("siswa_id", siswaId)
        .maybeSingle();
      return !!member;
    };

    // ---------- Daftar percakapan ----------
    if (action === "threads") {
      const { data: memberships, error: memberErr } = await admin
        .from("chat_members")
        .select("thread_id, last_read_at")
        .eq("siswa_id", siswaId);

      if (memberErr) {
        console.error("student-chat: gagal membaca anggota", memberErr.code);
        return json(500, { error: "Gagal membaca percakapan.", code: "lookup_failed" });
      }
      const ids = (memberships ?? []).map((m: { thread_id: string }) => m.thread_id);
      if (ids.length === 0) return json(200, { success: true, data: [] });

      const { data: threads, error: threadErr } = await admin
        .from("chat_threads")
        .select("id, tipe, judul, kelas_id, tugas_id, last_message_at")
        .in("id", ids)
        .order("last_message_at", { ascending: false });

      if (threadErr) {
        console.error("student-chat: gagal membaca thread", threadErr.code);
        return json(500, { error: "Gagal membaca percakapan.", code: "lookup_failed" });
      }

      const lastReadByThread = new Map<string, string | null>();
      for (const m of memberships ?? []) {
        lastReadByThread.set(m.thread_id as string, (m.last_read_at as string | null) ?? null);
      }

      // Nama lawan bicara untuk chat privat (guru).
      const directIds = (threads ?? [])
        .filter((t: { tipe: string }) => t.tipe === "direct")
        .map((t: { id: string }) => t.id);
      const guruByThread = new Map<string, string>();
      if (directIds.length > 0) {
        const { data: others } = await admin
          .from("chat_members")
          .select("thread_id, profiles:profile_id(full_name)")
          .in("thread_id", directIds)
          .not("profile_id", "is", null);
        for (const row of others ?? []) {
          const profile = (row as { profiles?: { full_name?: string } }).profiles;
          if (profile?.full_name) guruByThread.set(row.thread_id as string, profile.full_name);
        }
      }

      const withUnread: JsonMap[] = [];
      for (const t of threads ?? []) {
        const lastRead = lastReadByThread.get(t.id as string) ?? null;
        let unreadQuery = admin
          .from("chat_messages")
          .select("id", { count: "exact", head: true })
          .eq("thread_id", t.id);
        if (lastRead) unreadQuery = unreadQuery.gt("created_at", lastRead);
        const { count } = await unreadQuery;

        withUnread.push({
          ...t,
          judul: t.judul ?? guruByThread.get(t.id as string) ?? "Percakapan",
          unread: count ?? 0,
        });
      }

      return json(200, { success: true, data: withUnread });
    }

    // ---------- Riwayat pesan ----------
    if (action === "messages") {
      const threadId = String(body.thread_id ?? "").trim();
      if (!isUuid(threadId)) return json(400, { error: "thread_id tidak valid.", code: "invalid_thread" });
      if (!(await requireMember(threadId))) {
        return json(403, { error: "Anda bukan anggota percakapan ini.", code: "forbidden" });
      }
      const before = body.before ? String(body.before) : null;
      const limit = Math.min(Math.max(Number(body.limit ?? 30), 1), 100);

      let query = admin
        .from("chat_messages")
        .select("id, thread_id, sender_profile_id, sender_siswa_id, sender_nama, body, created_at")
        .eq("thread_id", threadId)
        .order("created_at", { ascending: false })
        .limit(limit);
      if (before && !Number.isNaN(Date.parse(before))) query = query.lt("created_at", before);

      const { data, error } = await query;
      if (error) {
        console.error("student-chat: gagal membaca pesan", error.code);
        return json(500, { error: "Gagal membaca pesan.", code: "lookup_failed" });
      }
      return json(200, { success: true, data: (data ?? []).reverse() });
    }

    // ---------- Kirim pesan ----------
    if (action === "send") {
      const threadId = String(body.thread_id ?? "").trim();
      const text = String(body.body ?? "").trim();
      const clientId = body.client_id ? String(body.client_id).slice(0, 64) : null;

      if (!isUuid(threadId)) return json(400, { error: "thread_id tidak valid.", code: "invalid_thread" });
      if (text.length < 1) return json(400, { error: "Pesan kosong.", code: "empty_message" });
      if (text.length > 2000) {
        return json(400, { error: "Pesan terlalu panjang (maks. 2000 karakter).", code: "message_too_long" });
      }
      if (!(await requireMember(threadId))) {
        return json(403, { error: "Anda bukan anggota percakapan ini.", code: "forbidden" });
      }

      const { data, error } = await admin
        .from("chat_messages")
        .insert({
          thread_id: threadId,
          sender_siswa_id: siswaId,
          sender_nama: siswa.nama,
          body: text,
          client_id: clientId,
        })
        .select("id, thread_id, sender_siswa_id, sender_nama, body, created_at")
        .single();

      if (error) {
        if (error.code === "23505") {
          // Duplikat client_id → pesan yang sama sudah tersimpan.
          const { data: existing } = await admin
            .from("chat_messages")
            .select("id, thread_id, sender_siswa_id, sender_nama, body, created_at")
            .eq("thread_id", threadId)
            .eq("client_id", clientId ?? "")
            .maybeSingle();
          return json(200, { success: true, duplicate: true, data: existing });
        }
        console.error("student-chat: gagal mengirim pesan", error.code);
        return json(500, { error: "Gagal mengirim pesan.", code: "insert_failed" });
      }
      return json(200, { success: true, data });
    }

    // ---------- Tandai dibaca ----------
    if (action === "mark_read") {
      const threadId = String(body.thread_id ?? "").trim();
      if (!isUuid(threadId)) return json(400, { error: "thread_id tidak valid.", code: "invalid_thread" });
      if (!(await requireMember(threadId))) {
        return json(403, { error: "Anda bukan anggota percakapan ini.", code: "forbidden" });
      }
      const { error } = await admin
        .from("chat_members")
        .update({ last_read_at: new Date().toISOString() })
        .eq("thread_id", threadId)
        .eq("siswa_id", siswaId);
      if (error) {
        console.error("student-chat: gagal menandai dibaca", error.code);
        return json(500, { error: "Gagal menandai pesan dibaca.", code: "update_failed" });
      }
      return json(200, { success: true });
    }

    // ---------- Daftar guru kelas (untuk memulai chat privat) ----------
    if (action === "guru_list") {
      if (!siswa.kelas_id) return json(200, { success: true, data: [] });

      const ids = new Set<string>();
      const { data: jadwalRows } = await admin
        .from("jadwal_pelajaran")
        .select("guru_id")
        .eq("kelas_id", siswa.kelas_id);
      for (const row of jadwalRows ?? []) {
        if (row.guru_id) ids.add(row.guru_id as string);
      }
      const { data: kelasRow } = await admin
        .from("kelas")
        .select("wali_kelas_id")
        .eq("id", siswa.kelas_id)
        .maybeSingle();
      if (kelasRow?.wali_kelas_id) ids.add(kelasRow.wali_kelas_id as string);

      if (ids.size === 0) return json(200, { success: true, data: [] });

      const { data: profiles, error } = await admin
        .from("profiles")
        .select("id, full_name")
        .in("id", Array.from(ids))
        .eq("is_active", true)
        .order("full_name", { ascending: true });

      if (error) {
        console.error("student-chat: gagal membaca guru", error.code);
        return json(500, { error: "Gagal membaca daftar guru.", code: "lookup_failed" });
      }
      return json(200, { success: true, data: profiles ?? [] });
    }

    // ---------- Buka percakapan privat dengan guru / grup kelas ----------
    if (action === "open_thread") {
      const tipe = String(body.tipe ?? "direct").trim();
      if (tipe !== "direct" && tipe !== "kelas") {
        return json(400, { error: "tipe harus direct atau kelas.", code: "invalid_tipe" });
      }

      if (tipe === "kelas") {
        if (!siswa.kelas_id) {
          return json(400, { error: "Siswa belum memiliki kelas.", code: "no_kelas" });
        }
        // Pakai thread kelas yang sudah ada, atau buat baru.
        const { data: existing } = await admin
          .from("chat_threads")
          .select("id, tipe, judul, kelas_id, tugas_id, last_message_at")
          .eq("tipe", "kelas")
          .eq("kelas_id", siswa.kelas_id)
          .maybeSingle();

        let thread = existing;
        if (!thread) {
          const { data: created, error } = await admin
            .from("chat_threads")
            .insert({
              tipe: "kelas",
              judul: "Grup Kelas",
              kelas_id: siswa.kelas_id,
            })
            .select("id, tipe, judul, kelas_id, tugas_id, last_message_at")
            .single();
          if (error) {
            console.error("student-chat: gagal membuat thread kelas", error.code);
            return json(500, { error: "Gagal membuka grup kelas.", code: "insert_failed" });
          }
          thread = created;
        }

        await admin
          .from("chat_members")
          .upsert(
            { thread_id: thread.id, siswa_id: siswaId, peran: "anggota" },
            { onConflict: "thread_id,siswa_id", ignoreDuplicates: true },
          );

        return json(200, { success: true, data: thread });
      }

      // direct: butuh guru_id yang mengampu kelas siswa.
      const guruId = String(body.guru_id ?? "").trim();
      if (!isUuid(guruId)) return json(400, { error: "guru_id tidak valid.", code: "invalid_guru" });

      const { data: guru } = await admin
        .from("profiles")
        .select("id, full_name, role, is_active")
        .eq("id", guruId)
        .maybeSingle();
      if (!guru || guru.role !== "guru" || guru.is_active !== true) {
        return json(404, { error: "Guru tidak ditemukan atau tidak aktif.", code: "guru_not_found" });
      }

      // Guru harus mengampu kelas siswa (relasi akademik).
      if (!siswa.kelas_id) {
        return json(400, { error: "Siswa belum memiliki kelas.", code: "no_kelas" });
      }
      const { data: relation } = await admin
        .from("jadwal_pelajaran")
        .select("id")
        .eq("guru_id", guruId)
        .eq("kelas_id", siswa.kelas_id)
        .limit(1)
        .maybeSingle();
      const { data: wali } = await admin
        .from("kelas")
        .select("id")
        .eq("id", siswa.kelas_id)
        .eq("wali_kelas_id", guruId)
        .maybeSingle();

      if (!relation && !wali) {
        return json(403, {
          error: "Anda hanya dapat mengobrol dengan guru yang mengajar di kelas Anda.",
          code: "no_relation",
        });
      }

      // Thread direct unik per (guru, siswa): cari lewat anggota.
      const { data: myThreads } = await admin
        .from("chat_members")
        .select("thread_id")
        .eq("siswa_id", siswaId);
      const myThreadIds = (myThreads ?? []).map((r: { thread_id: string }) => r.thread_id);

      let threadId: string | null = null;
      if (myThreadIds.length > 0) {
        const { data: guruThreads } = await admin
          .from("chat_members")
          .select("thread_id")
          .eq("profile_id", guruId)
          .in("thread_id", myThreadIds);
        const candidates = (guruThreads ?? []).map((r: { thread_id: string }) => r.thread_id);
        if (candidates.length > 0) {
          const { data: direct } = await admin
            .from("chat_threads")
            .select("id")
            .eq("tipe", "direct")
            .in("id", candidates)
            .limit(1)
            .maybeSingle();
          threadId = (direct?.id as string | undefined) ?? null;
        }
      }

      if (!threadId) {
        const { data: created, error } = await admin
          .from("chat_threads")
          .insert({ tipe: "direct", judul: guru.full_name })
          .select("id")
          .single();
        if (error) {
          console.error("student-chat: gagal membuat thread direct", error.code);
          return json(500, { error: "Gagal membuka percakapan.", code: "insert_failed" });
        }
        threadId = created.id as string;

        await admin.from("chat_members").insert([
          { thread_id: threadId, profile_id: guruId, peran: "pengelola" },
          { thread_id: threadId, siswa_id: siswaId, peran: "anggota" },
        ]);
      }

      const { data: thread } = await admin
        .from("chat_threads")
        .select("id, tipe, judul, kelas_id, tugas_id, last_message_at")
        .eq("id", threadId)
        .maybeSingle();

      return json(200, { success: true, data: thread });
    }

    return json(400, {
      error: "action tidak dikenal. Gunakan threads, messages, send, mark_read, open_thread.",
      code: "invalid_action",
    });
  } catch (e) {
    console.error("student-chat: unexpected", e instanceof Error ? e.message : String(e));
    return json(500, { error: "Terjadi kesalahan internal pada server.", code: "internal_error" });
  }
});
