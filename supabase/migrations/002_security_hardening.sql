-- ======================================================
-- 002_security_hardening.sql
-- Jalankan SETELAH Edge Function student-access & update-student-task-status
-- di-deploy ulang (versi token bertanda tangan HMAC).
-- Idempotent: aman dijalankan berulang.
-- ======================================================

-- 1) ANON TIDAK BOLEH MEMBACA kode_akses
--    Sebelumnya policy "Public can read siswa ... using (true)" + grant SELECT penuh
--    membuat siapa pun dengan anon key bisa membaca SEMUA kode_akses siswa dan
--    memakainya untuk mengaku sebagai siswa lain.
--    Solusi: tetap izinkan anon membaca kolom non-sensitif (untuk daftar kelas dsb),
--    tetapi kode_akses hanya bisa dibaca lewat Edge Function (service_role).
revoke select on table public.siswa from anon;
grant select (id, nomor_induk, nama, kelas_id, status_aktif, created_at, updated_at)
  on table public.siswa to anon;

-- Guru/admin (authenticated) tetap membutuhkan kode_akses untuk mengelola data siswa.
grant select on table public.siswa to authenticated;

-- 2) Pastikan RLS tetap aktif pada semua tabel inti
alter table public.profiles enable row level security;
alter table public.siswa enable row level security;
alter table public.kelas enable row level security;
alter table public.mata_pelajaran enable row level security;
alter table public.guru_mapel enable row level security;
alter table public.jadwal_pelajaran enable row level security;
alter table public.tugas enable row level security;
alter table public.status_tugas_siswa enable row level security;

-- 3) Anon tidak boleh menulis ke status_tugas_siswa (validasi hanya lewat Edge Function)
drop policy if exists "Anon cannot modify status" on public.status_tugas_siswa;

-- 4) Cek cepat: pastikan tidak ada policy SELECT anon yang membuka kode_akses
--    (query manual, tidak mengubah data)
-- select grantee, privilege_type, column_name
-- from information_schema.column_privileges
-- where table_name = 'siswa' and grantee in ('anon','authenticated');
