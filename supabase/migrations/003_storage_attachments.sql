-- ======================================================
-- 003_storage_attachments.sql
-- Perbaikan error:
--   StorageException: new row violates row-level security policy,
--   statusCode: 403, error: Unauthorized
--
-- AKAR MASALAH (terbukti dari repositori):
--   1. Bucket `lampiran-tugas` TIDAK PERNAH dibuat oleh migration mana pun —
--      hanya ada komentar "buat manual di dashboard" di 001_initial_schema.sql.
--   2. Policy `storage.objects` untuk bucket tersebut juga hanya komentar
--      (tidak pernah dieksekusi), sehingga INSERT selalu ditolak RLS → 403.
--   3. Path lama '${timestamp}_${nama_file}' diletakkan di root bucket tanpa
--      identitas pemilik, sehingga policy berbasis kepemilikan tidak mungkin dibuat.
--
-- KONTRAK PATH BARU (wajib sama dengan lib/shared/services/attachment_service.dart):
--   tugas/<guru_id>/<tugas_id>/<uuid>.<ext>
--   → split_part(name,'/',1) = 'tugas'
--   → split_part(name,'/',2) = guru_id
--   → split_part(name,'/',3) = tugas_id
--
-- Jalankan SETELAH 001 & 002, dan SEBELUM guru mencoba upload lampiran.
-- Idempotent: aman dijalankan berulang.
-- ======================================================

-- 1) Bucket privat (bukan public). Akses siswa memakai signed URL jangka pendek.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lampiran-tugas',
  'lampiran-tugas',
  false,
  10485760, -- 10 MB
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'image/jpeg',
    'image/png',
    'application/zip',
    'application/x-zip-compressed',
    'application/vnd.rar',
    'application/x-rar-compressed',
    'text/plain'
  ]
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 2) Policy storage.objects
--    Semua policy lama untuk bucket ini dihapus dulu agar tidak ada sisa aturan
--    permisif dari percobaan sebelumnya.
drop policy if exists "Public read lampiran" on storage.objects;
drop policy if exists "Guru can upload lampiran" on storage.objects;
drop policy if exists "Admin/Guru can delete lampiran" on storage.objects;
drop policy if exists "lampiran: guru upload" on storage.objects;
drop policy if exists "lampiran: guru update" on storage.objects;
drop policy if exists "lampiran: guru delete" on storage.objects;
drop policy if exists "lampiran: baca pemilik" on storage.objects;
drop policy if exists "lampiran: baca siswa (tugas published)" on storage.objects;
drop policy if exists "lampiran: admin kelola" on storage.objects;

-- 2a) BACA: admin, guru pemilik path, atau siapa pun (termasuk siswa anon)
--     selama file benar-benar direferensikan oleh tugas yang sudah published.
--     Bucket tetap privat: file tidak bisa diakses tanpa signed URL.
create policy "lampiran: baca pemilik"
on storage.objects for select
to authenticated
using (
  bucket_id = 'lampiran-tugas'
  and (
    public.is_admin()
    or split_part(name, '/', 2) = auth.uid()::text
  )
);

create policy "lampiran: baca siswa (tugas published)"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'lampiran-tugas'
  and exists (
    select 1
    from public.tugas t
    where t.lampiran_path = storage.objects.name
      and t.status_publikasi = 'published'
  )
);

-- 2b) INSERT: hanya guru pemilik tugas (path harus menunjuk tugas miliknya),
--     atau admin. Validasi MIME/ukuran juga dilakukan di level bucket.
create policy "lampiran: guru upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'lampiran-tugas'
  and (
    public.is_admin()
    or (
      split_part(name, '/', 1) = 'tugas'
      and split_part(name, '/', 2) = auth.uid()::text
      and exists (
        select 1
        from public.tugas t
        where t.id::text = split_part(storage.objects.name, '/', 3)
          and t.guru_id = auth.uid()
      )
    )
  )
);

-- 2c) UPDATE (mis. upsert metadata / replace): sama dengan INSERT.
create policy "lampiran: guru update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'lampiran-tugas'
  and (public.is_admin() or split_part(name, '/', 2) = auth.uid()::text)
)
with check (
  bucket_id = 'lampiran-tugas'
  and (
    public.is_admin()
    or (
      split_part(name, '/', 1) = 'tugas'
      and split_part(name, '/', 2) = auth.uid()::text
      and exists (
        select 1
        from public.tugas t
        where t.id::text = split_part(storage.objects.name, '/', 3)
          and t.guru_id = auth.uid()
      )
    )
  )
);

-- 2d) DELETE: admin atau guru pemilik path.
create policy "lampiran: guru delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'lampiran-tugas'
  and (public.is_admin() or split_part(name, '/', 2) = auth.uid()::text)
);

-- 3) Bersihkan file yatim: path gaya lama (tanpa folder) TIDAK bisa dipetakan
--    ke pemilik sehingga tidak bisa dibaca lewat policy baru.
--    File tersebut juga tidak lagi dirujuk oleh kolom lampiran_path setelah
--    aplikasi versi baru menyimpan path berbentuk tugas/<guru>/<tugas>/<file>.
--    (Tidak menghapus data di sini — hanya catatan audit.)
do $$
declare
  orphan_count integer;
begin
  select count(*) into orphan_count
  from storage.objects o
  where o.bucket_id = 'lampiran-tugas'
    and split_part(o.name, '/', 1) <> 'tugas';

  if orphan_count > 0 then
    raise notice 'Ada % objek lampiran dengan path lama. Unggah ulang lampiran dari aplikasi versi baru agar dapat diakses.', orphan_count;
  end if;
end;
$$;

-- 4) Verifikasi cepat (jalankan manual bila perlu):
-- select policyname, cmd, roles, qual, with_check
-- from pg_policies where schemaname = 'storage' and tablename = 'objects'
--   and policyname like 'lampiran:%';
