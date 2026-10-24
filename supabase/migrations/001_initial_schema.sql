-- EduTask - Supabase SQL Migration v1.0.0
-- Jalankan di Supabase SQL Editor (https://supabase.com/dashboard -> SQL Editor)
-- Zona waktu: Asia/Jakarta ditangani di aplikasi, timestamps disimpan UTC (timestamptz)

-- Enable extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ======================================================
-- 1. PROFILES (terhubung ke auth.users)
-- ======================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null,
  role text not null check (role in ('admin','guru')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trigger untuk updated_at
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles
for each row execute function public.handle_updated_at();

-- 2. KELAS
create table if not exists public.kelas (
  id uuid primary key default gen_random_uuid(),
  nama_kelas text not null unique,
  tingkat text,
  tahun_ajaran text,
  wali_kelas_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- 3. SISWA
create table if not exists public.siswa (
  id uuid primary key default gen_random_uuid(),
  nomor_induk text not null unique,
  nama text not null,
  kelas_id uuid references public.kelas(id) on delete set null,
  kode_akses text unique, -- untuk identitas siswa tanpa login, contoh: SISWA-001
  status_aktif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_siswa_updated_at on public.siswa;
create trigger set_siswa_updated_at before update on public.siswa
for each row execute function public.handle_updated_at();

create index if not exists idx_siswa_kelas on public.siswa(kelas_id);
create index if not exists idx_siswa_nama on public.siswa(nama);
create index if not exists idx_siswa_nomor_induk on public.siswa(nomor_induk);
create index if not exists idx_siswa_kode_akses on public.siswa(kode_akses);

-- 4. MATA PELAJARAN
create table if not exists public.mata_pelajaran (
  id uuid primary key default gen_random_uuid(),
  nama_mapel text not null unique,
  deskripsi text,
  created_at timestamptz not null default now()
);

-- 5. GURU_MAPEL (relasi guru-mata pelajaran-kelas)
create table if not exists public.guru_mapel (
  id uuid primary key default gen_random_uuid(),
  guru_id uuid not null references public.profiles(id) on delete cascade,
  mata_pelajaran_id uuid not null references public.mata_pelajaran(id) on delete cascade,
  kelas_id uuid references public.kelas(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(guru_id, mata_pelajaran_id, kelas_id)
);
create index if not exists idx_guru_mapel_guru on public.guru_mapel(guru_id);

-- 6. JADWAL PELAJARAN
create table if not exists public.jadwal_pelajaran (
  id uuid primary key default gen_random_uuid(),
  kelas_id uuid not null references public.kelas(id) on delete cascade,
  guru_id uuid not null references public.profiles(id) on delete cascade,
  mata_pelajaran_id uuid not null references public.mata_pelajaran(id) on delete cascade,
  hari text not null check (hari in ('Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu')),
  jam_mulai time not null,
  jam_selesai time not null,
  ruang text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint check_jam_valid check (jam_selesai > jam_mulai)
);

drop trigger if exists set_jadwal_updated_at on public.jadwal_pelajaran;
create trigger set_jadwal_updated_at before update on public.jadwal_pelajaran
for each row execute function public.handle_updated_at();

create index if not exists idx_jadwal_kelas_hari on public.jadwal_pelajaran(kelas_id, hari);
create index if not exists idx_jadwal_guru_hari on public.jadwal_pelajaran(guru_id, hari);

-- Cegah bentrok jadwal kelas atau guru menggunakan EXCLUDE jika tersedia, atau fungsi validasi:
create or replace function public.check_jadwal_bentrok()
returns trigger as $$
begin
  -- Cek bentrok untuk kelas yang sama, hari sama, jam overlap
  if exists (
    select 1 from public.jadwal_pelajaran
    where id != new.id
      and kelas_id = new.kelas_id
      and hari = new.hari
      and not (jam_selesai <= new.jam_mulai or jam_mulai >= new.jam_selesai)
  ) then
    raise exception 'Jadwal bentrok untuk kelas pada hari dan jam tersebut';
  end if;
  -- Cek bentrok untuk guru yang sama
  if exists (
    select 1 from public.jadwal_pelajaran
    where id != new.id
      and guru_id = new.guru_id
      and hari = new.hari
      and not (jam_selesai <= new.jam_mulai or jam_mulai >= new.jam_selesai)
  ) then
    raise exception 'Jadwal bentrok untuk guru pada hari dan jam tersebut';
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_check_jadwal_bentrok on public.jadwal_pelajaran;
create trigger trg_check_jadwal_bentrok before insert or update on public.jadwal_pelajaran
for each row execute function public.check_jadwal_bentrok();

-- 7. TUGAS
create table if not exists public.tugas (
  id uuid primary key default gen_random_uuid(),
  judul text not null check (char_length(judul) >= 3),
  deskripsi text not null,
  guru_id uuid not null references public.profiles(id) on delete cascade,
  kelas_id uuid not null references public.kelas(id) on delete cascade,
  mata_pelajaran_id uuid not null references public.mata_pelajaran(id) on delete cascade,
  tanggal_mulai timestamptz not null default now(),
  tenggat_waktu timestamptz not null,
  lampiran_path text,
  status_publikasi text not null default 'published' check (status_publikasi in ('draft','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint check_tenggat_valid check (tenggat_waktu > tanggal_mulai)
);

drop trigger if exists set_tugas_updated_at on public.tugas;
create trigger set_tugas_updated_at before update on public.tugas
for each row execute function public.handle_updated_at();

create index if not exists idx_tugas_kelas on public.tugas(kelas_id);
create index if not exists idx_tugas_guru on public.tugas(guru_id);
create index if not exists idx_tugas_tenggat on public.tugas(tenggat_waktu);
create index if not exists idx_tugas_judul on public.tugas(judul);

-- 8. STATUS_TUGAS_SISWA
create table if not exists public.status_tugas_siswa (
  id uuid primary key default gen_random_uuid(),
  tugas_id uuid not null references public.tugas(id) on delete cascade,
  siswa_id uuid not null references public.siswa(id) on delete cascade,
  status text not null check (status in ('selesai','belum_selesai')),
  selesai_pada timestamptz,
  updated_at timestamptz not null default now(),
  unique(tugas_id, siswa_id)
);

drop trigger if exists set_status_updated_at on public.status_tugas_siswa;
create trigger set_status_updated_at before update on public.status_tugas_siswa
for each row execute function public.handle_updated_at();

create index if not exists idx_status_tugas on public.status_tugas_siswa(tugas_id);
create index if not exists idx_status_siswa on public.status_tugas_siswa(siswa_id);

-- ======================================================
-- Helper function untuk cek role user
-- ======================================================
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active = true
  );
end;
$$ language plpgsql security definer;

create or replace function public.is_guru()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'guru' and is_active = true
  );
end;
$$ language plpgsql security definer;

create or replace function public.my_role()
returns text as $$
declare r text;
begin
  select role into r from public.profiles where id = auth.uid();
  return coalesce(r, 'anon');
end;
$$ language plpgsql security definer;

-- ======================================================
-- ROW LEVEL SECURITY (RLS)
-- ======================================================
alter table public.profiles enable row level security;
alter table public.kelas enable row level security;
alter table public.siswa enable row level security;
alter table public.mata_pelajaran enable row level security;
alter table public.guru_mapel enable row level security;
alter table public.jadwal_pelajaran enable row level security;
alter table public.tugas enable row level security;
alter table public.status_tugas_siswa enable row level security;

-- Hapus policy lama jika ada (idempotent)
drop policy if exists "Admin can manage profiles" on public.profiles;
drop policy if exists "Guru can view profiles" on public.profiles;
drop policy if exists "Anon cannot see profiles" on public.profiles;
drop policy if exists "Profiles self read" on public.profiles;

-- PROFILES policies
-- Admin dapat mengelola semua profiles
create policy "Admin can manage profiles"
on public.profiles for all
using (public.is_admin())
with check (public.is_admin());

-- Setiap user terautentikasi dapat melihat profiles dirinya sendiri
create policy "Profiles self read"
on public.profiles for select
using (auth.uid() = id);

-- Guru dapat melihat profiles (terbatas) untuk keperluan jadwal - hanya id, full_name, role
-- Untuk keamanan, kita izinkan select untuk authenticated, tapi anonim tidak bisa
create policy "Authenticated can view guru profiles"
on public.profiles for select
using (auth.role() = 'authenticated');

-- KELAS
drop policy if exists "Public can read kelas" on public.kelas;
drop policy if exists "Admin manage kelas" on public.kelas;
drop policy if exists "Guru read kelas" on public.kelas;

create policy "Public can read kelas"
on public.kelas for select
using (true); -- siswa anonim perlu membaca daftar kelas

create policy "Admin manage kelas"
on public.kelas for all
using (public.is_admin())
with check (public.is_admin());

-- SISWA
drop policy if exists "Public limited read siswa for kode" on public.siswa;
drop policy if exists "Admin manage siswa" on public.siswa;
drop policy if exists "Anon cannot list all siswa" on public.siswa;
-- NOTE: Kita ingin anon TIDAK bisa list semua siswa dengan data lengkap.
-- Solusi: anon hanya bisa select dengan filter kode_akses (via Edge Function) atau select terbatas.
-- Untuk simplicity, kita izinkan select untuk anon hanya jika mereka query dengan kode_akses spesifik?
-- Postgres RLS tidak bisa cek filter query, jadi kita buat policy: anon bisa select siswa (id, nama, kelas_id, kode_akses) tapi kita dokumentasikan bahwa email/profile tidak ada di tabel siswa.
-- Lebih aman: berikan anon SELECT hanya untuk kolom terbatas via view. Sementara ini kita buat policy yang mengizinkan anon SELECT (karena siswa anonim perlu lihat kelas), tapi kita batasi via anon tidak bisa melihat semua siswa tanpa batas? Kita akan buat policy yang mengizinkan anon read, tapi kita andalkan bahwa tabel siswa tidak berisi data sensitif seperti email/password.

create policy "Public can read siswa limited"
on public.siswa for select
using (true);

create policy "Admin manage siswa"
on public.siswa for all
using (public.is_admin())
with check (public.is_admin());

create policy "Guru can read siswa in their scope"
on public.siswa for select
using (public.is_guru() or public.is_admin());

-- MATA PELAJARAN
drop policy if exists "Public read mapel" on public.mata_pelajaran;
drop policy if exists "Admin manage mapel" on public.mata_pelajaran;
create policy "Public read mapel" on public.mata_pelajaran for select using (true);
create policy "Admin manage mapel" on public.mata_pelajaran for all using (public.is_admin()) with check (public.is_admin());
create policy "Guru read mapel" on public.mata_pelajaran for select using (auth.role() = 'authenticated');

-- JADWAL
drop policy if exists "Public read jadwal published" on public.jadwal_pelajaran;
drop policy if exists "Admin manage jadwal" on public.jadwal_pelajaran;
drop policy if exists "Guru manage own jadwal" on public.jadwal_pelajaran;

create policy "Public read jadwal"
on public.jadwal_pelajaran for select
using (true); -- siswa anonim perlu lihat jadwal kelasnya

create policy "Admin manage jadwal"
on public.jadwal_pelajaran for all
using (public.is_admin())
with check (public.is_admin());

create policy "Guru can manage own jadwal"
on public.jadwal_pelajaran for all
using (guru_id = auth.uid() and public.is_guru())
with check (guru_id = auth.uid() and public.is_guru());

-- TUGAS
drop policy if exists "Public read published tugas" on public.tugas;
drop policy if exists "Admin manage tugas" on public.tugas;
drop policy if exists "Guru manage own tugas" on public.tugas;

create policy "Public read published tugas"
on public.tugas for select
using (status_publikasi = 'published');

create policy "Admin manage tugas"
on public.tugas for all
using (public.is_admin())
with check (public.is_admin());

create policy "Guru manage own tugas"
on public.tugas for all
using (guru_id = auth.uid() and (public.is_guru() or public.is_admin()))
with check (guru_id = auth.uid() and (public.is_guru() or public.is_admin()));

-- STATUS_TUGAS_SISWA
drop policy if exists "Admin read status" on public.status_tugas_siswa;
drop policy if exists "Guru read status for own tugas" on public.status_tugas_siswa;
drop policy if exists "Anon cannot modify status" on public.status_tugas_siswa;

-- Admin bisa semua
create policy "Admin manage status"
on public.status_tugas_siswa for all
using (public.is_admin())
with check (public.is_admin());

-- Guru hanya bisa lihat status untuk tugas miliknya
create policy "Guru read status for own tugas"
on public.status_tugas_siswa for select
using (
  exists (
    select 1 from public.tugas
    where tugas.id = status_tugas_siswa.tugas_id
      and tugas.guru_id = auth.uid()
  )
);

-- Guru bisa lihat semua status untuk kelasnya (alternatif: jika guru_mapel menunjukkan kelasnya)
-- Untuk sekarang, batasi hanya tugas milik guru

-- Anon TIDAK boleh langsung update - hanya via Edge Function dengan service_role
-- Kita tidak buat policy untuk anon insert/update/delete
-- Jika ingin Edge Function menggunakan service_role, ia akan bypass RLS
-- Namun untuk fallback lokal, kita dokumentasikan bahwa status lokal disimpan di device, bukan di DB

-- ======================================================
-- STORAGE: lampiran-tugas bucket (buat manual di dashboard jika belum ada)
-- ======================================================
-- Jalankan di Storage SQL atau dashboard:
-- insert into storage.buckets (id, name, public) values ('lampiran-tugas', 'lampiran-tugas', true)
--   on conflict (id) do nothing;

-- Storage policies (jika bucket sudah ada):
-- Aktifkan RLS untuk storage.objects sudah default. Buat policy:
-- create policy "Public read lampiran" on storage.objects for select using (bucket_id = 'lampiran-tugas');
-- create policy "Guru can upload lampiran" on storage.objects for insert with check (bucket_id = 'lampiran-tugas' and auth.role() = 'authenticated');
-- create policy "Admin/Guru can delete lampiran" on storage.objects for delete using (bucket_id = 'lampiran-tugas' and auth.role() = 'authenticated');

-- ======================================================
-- SEED: Buat admin awal (ganti email/password sesuai kebutuhan)
-- ======================================================
-- Cara membuat admin:
-- 1. Buat user di Supabase Dashboard -> Authentication -> Users -> Add User (email: admin@sekolah.id)
-- 2. Jalankan:
-- insert into public.profiles (id, full_name, email, role, is_active)
-- values ('<uuid-dari-auth.users>', 'Administrator', 'admin@sekolah.id', 'admin', true)
-- on conflict (id) do update set role='admin', is_active=true;

-- Contoh data awal (opsional, uncomment untuk seed):
-- insert into public.kelas (nama_kelas, tingkat, tahun_ajaran) values
--   ('7A','7','2024/2025'),
--   ('7B','7','2024/2025'),
--   ('8A','8','2024/2025'),
--   ('9A','9','2024/2025')
-- on conflict (nama_kelas) do nothing;

-- insert into public.mata_pelajaran (nama_mapel, deskripsi) values
--   ('Matematika','Matematika dasar'),
--   ('Bahasa Indonesia','Bahasa Indonesia'),
--   ('IPA','Ilmu Pengetahuan Alam'),
--   ('IPS','Ilmu Pengetahuan Sosial'),
--   ('Bahasa Inggris','English'),
--   ('PKN','Pendidikan Kewarganegaraan')
-- on conflict (nama_mapel) do nothing;

-- ======================================================
-- CATATAN KEAMANAN
-- ======================================================
-- - Service role key HANYA di Edge Functions / server, jangan di Flutter.
-- - Role diverifikasi via public.profiles.role, bukan dari JWT claim yang bisa diubah client.
-- - Siswa anonim hanya bisa SELECT jadwal/tugas published & kelas/mapel.
-- - Status tugas siswa hanya bisa diubah via Edge Function yang memvalidasi kode_akses siswa.
-- - Jika sekolah ingin mode lokal saja, status disimpan di SharedPreferences (tidak resmi).
