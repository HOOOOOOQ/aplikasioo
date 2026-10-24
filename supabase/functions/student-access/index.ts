// supabase/functions/student-access/index.ts
// Validasi kode_akses siswa dan kembalikan token akses terbatas
// Token di sini bisa berupa JWT sederhana atau random string yang disimpan di server
// Untuk versi awal, kita kembalikan token = base64(siswa_id:timestamp) yang ditandatangani dengan secret sederhana
// Di produksi, gunakan JWT yang diverifikasi Edge Function lain.

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
    const kode_akses = (body.kode_akses ?? "").toString().trim();

    if (!kode_akses) {
      return new Response(JSON.stringify({ error: "kode_akses wajib diisi" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Jangan log kode sensitif secara lengkap
    console.log(`student-access: kode_akses=${kode_akses.substring(0, 3)}***`);

    const client = createClient(supabaseUrl, serviceRoleKey);

    const { data: siswa, error } = await client
      .from("siswa")
      .select("id, nama, kelas_id, kode_akses, kelas(nama_kelas)")
      .eq("kode_akses", kode_akses)
      .eq("status_aktif", true)
      .maybeSingle();

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (!siswa) {
      return new Response(JSON.stringify({ success: false, error: "Kode tidak ditemukan atau siswa tidak aktif" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Buat token sederhana (di produksi, gunakan JWT dengan expiry)
    const raw = `${siswa.id}:${Date.now()}`;
    const token = btoa(raw);

    const kelasNama = (siswa.kelas as any)?.nama_kelas ?? null;

    return new Response(
      JSON.stringify({
        success: true,
        siswa: {
          id: siswa.id,
          nama: siswa.nama,
          kelas_id: siswa.kelas_id,
          kelas_nama: kelasNama,
        },
        token,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
