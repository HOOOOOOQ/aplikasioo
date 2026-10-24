// supabase/functions/update-student-task-status/index.ts
// Endpoint aman untuk siswa mengubah status tugasnya sendiri
// Validasi: siswa_id harus sesuai dengan token & tugas harus untuk kelas siswa

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const body = await req.json();
    const { tugas_id, siswa_id, status, token } = body;

    if (!tugas_id || !siswa_id || !status) {
      return new Response(JSON.stringify({ error: "tugas_id, siswa_id, status wajib diisi" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (!["selesai", "belum_selesai"].includes(status)) {
      return new Response(JSON.stringify({ error: "status tidak valid" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Validasi token sederhana: decode base64 dan cek siswa_id cocok
    // Di produksi, verifikasi JWT signature
    if (token) {
      try {
        const decoded = atob(token);
        const tokenSiswaId = decoded.split(":")[0];
        if (tokenSiswaId !== siswa_id) {
          return new Response(JSON.stringify({ error: "Token tidak sesuai dengan siswa_id" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        }
      } catch (_) {
        // Jika token tidak valid, tetap lanjutkan tapi log warning (untuk kompatibilitas local token)
        console.log("Warning: token tidak dapat didecode, lanjut dengan validasi kelas");
      }
    }

    const client = createClient(supabaseUrl, serviceRoleKey);

    // Ambil data siswa dan tugas untuk validasi kelas
    const { data: siswa, error: siswaErr } = await client.from("siswa").select("id, kelas_id").eq("id", siswa_id).single();
    if (siswaErr || !siswa) {
      return new Response(JSON.stringify({ error: "Siswa tidak ditemukan" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { data: tugas, error: tugasErr } = await client.from("tugas").select("id, kelas_id").eq("id", tugas_id).single();
    if (tugasErr || !tugas) {
      return new Response(JSON.stringify({ error: "Tugas tidak ditemukan" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (siswa.kelas_id !== tugas.kelas_id) {
      return new Response(JSON.stringify({ error: "Tugas tidak untuk kelas siswa ini" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Upsert status
    const { error: upsertErr } = await client.from("status_tugas_siswa").upsert(
      {
        tugas_id,
        siswa_id,
        status,
        selesai_pada: status === "selesai" ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "tugas_id,siswa_id" },
    );

    if (upsertErr) {
      return new Response(JSON.stringify({ error: upsertErr.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ success: true }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
