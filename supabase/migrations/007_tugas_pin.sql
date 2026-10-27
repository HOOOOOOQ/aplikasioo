-- ======================================================
-- 007_tugas_pin.sql
--
-- TUJUAN
--   Menambahkan kemampuan **pin tugas** (prioritas tampil di atas) plus
--   urutan manual di antara tugas yang di-pin.
--
--   * `tugas.is_pinned`  boolean NOT NULL DEFAULT false
--   * `tugas.position`   integer NOT NULL DEFAULT 0  (kecil = lebih atas)
--
-- SIFAT
--   * Idempoten: aman dijalankan berulang (add column if not exists,
--     drop constraint if exists + create, create index if not exists,
--     create or replace function).
--   * Non-destruktif: TIDAK menghapus/mengubah data lama. Semua baris lama
--     otomatis bernilai `is_pinned = false, position = 0`, sehingga urutan
--     daftar tugas tetap sama seperti sebelum migration (urut tenggat).
--   * RLS tidak dilemahkan. Tidak ada policy baru yang memperluas akses:
--     penulisan pin memakai policy `tugas` yang sudah ada
--     ("Admin manage tugas" & "Guru manage own tugas") ditambah pemeriksaan
--     ulang di dalam RPC `set_tugas_pin`.
--   * Tidak memakai service_role.
--
-- OTORISASI (server-side, bukan sekadar UI)
--   * RLS `tugas` hanya mengizinkan UPDATE bagi admin atau guru pemilik baris.
--   * RPC `set_tugas_pin` berjalan dengan hak pemanggil (SECURITY INVOKER)
--     sehingga RLS tetap berlaku, lalu memeriksa ulang:
--       - wajib login (auth.uid() tidak null),
--       - admin ATAU guru pemilik tugas (`guru_id = auth.uid()`).
--   * Siswa/anon tidak punya policy UPDATE pada `tugas`, jadi permintaan
--     mereka ditolak (0 baris / 42501) meskipun UI-nya dimanipulasi.
-- ======================================================

-- ------------------------------------------------------
-- 1) Kolom pin & urutan (idempoten, aman untuk data lama)
-- ------------------------------------------------------
alter table public.tugas
  add column if not exists is_pinned boolean not null default false;

alter table public.tugas
  add column if not exists "position" integer not null default 0;

-- Pastikan tidak ada NULL pada data lama (kolom mungkin sudah ada dari
-- percobaan sebelumnya dengan definisi yang berbeda).
update public.tugas set is_pinned = false where is_pinned is null;
update public.tugas set "position" = 0 where "position" is null;

alter table public.tugas alter column is_pinned set not null;
alter table public.tugas alter column is_pinned set default false;
alter table public.tugas alter column "position" set not null;
alter table public.tugas alter column "position" set default 0;

-- Batas wajar posisi: mencegah nilai ekstrem dari klien lama / bug.
-- `not valid` membuat penambahan constraint tidak memindai ulang seluruh tabel
-- besar (data lama sudah pasti memenuhi karena default 0).
alter table public.tugas drop constraint if exists check_tugas_position;
alter table public.tugas
  add constraint check_tugas_position check ("position" >= 0 and "position" <= 1000000) not valid;

-- ------------------------------------------------------
-- 2) Index urutan (mendukung ORDER BY pin, position, tenggat)
-- ------------------------------------------------------
create index if not exists idx_tugas_pinned_order
  on public.tugas (is_pinned desc, "position" asc, tenggat_waktu asc, id asc);

create index if not exists idx_tugas_pinned_only
  on public.tugas (is_pinned)
  where is_pinned = true;

-- ------------------------------------------------------
-- 3) RPC set_tugas_pin
--    SECURITY INVOKER (default) => RLS tetap berlaku.
--    Penguncian advisory mencegah dua pengguna mendapat posisi yang sama
--    saat menekan pin hampir bersamaan.
-- ------------------------------------------------------
create or replace function public.set_tugas_pin(
  p_tugas_id uuid,
  p_pinned boolean,
  p_position integer default null
)
returns public.tugas
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.tugas;
  v_next integer;
  v_position integer;
begin
  if v_uid is null then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'Permintaan harus memakai sesi login (admin atau guru).';
  end if;

  if p_pinned is null then
    raise exception 'invalid_payload' using errcode = '22023',
      hint = 'p_pinned wajib bernilai true atau false.';
  end if;

  -- Baca baris target. Bila RLS tidak mengizinkan, baris tidak terlihat dan
  -- fungsi berhenti dengan pesan yang jelas (bukan diam-diam sukses).
  select * into v_row from public.tugas where id = p_tugas_id;
  if not found then
    raise exception 'not_found' using errcode = 'P0002',
      hint = 'Tugas tidak ditemukan atau tidak dapat diakses oleh akun ini.';
  end if;

  -- Pemeriksaan ulang otorisasi di sisi server (bukan hanya RLS).
  if not (public.is_admin() or (public.is_guru() and v_row.guru_id = v_uid)) then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'Hanya admin atau guru pemilik tugas yang boleh mengubah pin.';
  end if;

  if p_pinned then
    if p_position is null then
      -- Serialisasi penentuan posisi agar tidak ada dua penulis yang membaca
      -- max(position) yang sama pada saat bersamaan.
      perform pg_advisory_xact_lock(hashtext('public.tugas.pin_position'));
      select coalesce(max("position"), -1) + 1
        into v_next
        from public.tugas
       where is_pinned = true;
      v_position := least(greatest(coalesce(v_next, 0), 0), 1000000);
    else
      v_position := least(greatest(p_position, 0), 1000000);
    end if;
  else
    -- Melepas pin: posisi dikembalikan ke 0 agar tidak menyisakan celah urutan.
    v_position := 0;
  end if;

  update public.tugas
     set is_pinned = p_pinned,
         "position" = v_position
   where id = p_tugas_id
  returning * into v_row;

  -- UPDATE ... RETURNING INTO pada 0 baris membuat v_row menjadi NULL dan
  -- FOUND = false. Keduanya diperiksa agar kegagalan RLS tidak pernah
  -- dilaporkan sebagai sukses.
  if not found or v_row.id is null then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'Perubahan ditolak oleh kebijakan keamanan baris.';
  end if;

  return v_row;
end;
$$;

comment on function public.set_tugas_pin(uuid, boolean, integer) is
  'Pin/unpin tugas. Otorisasi: admin atau guru pemilik tugas (dicek ulang di server). Posisi null = otomatis di akhir daftar pin.';

revoke all on function public.set_tugas_pin(uuid, boolean, integer) from public, anon;
grant execute on function public.set_tugas_pin(uuid, boolean, integer) to authenticated, service_role;

-- ------------------------------------------------------
-- 4) Muat ulang schema cache PostgREST
--    Agar kolom baru & RPC langsung dikenali tanpa restart.
-- ------------------------------------------------------
notify pgrst, 'reload schema';

-- ------------------------------------------------------
-- 5) Verifikasi manual (jalankan setelah migration)
-- ------------------------------------------------------
-- -- kolom ada?
-- select column_name, data_type, is_nullable, column_default
--   from information_schema.columns
--  where table_schema = 'public' and table_name = 'tugas'
--    and column_name in ('is_pinned', 'position');
--
-- -- fungsi ada?
-- select to_regprocedure('public.set_tugas_pin(uuid,boolean,integer)');
--
-- -- data lama aman?
-- select count(*) filter (where is_pinned) as dipin,
--        count(*) filter (where "position" <> 0) as posisi_non_nol,
--        count(*) as total
--   from public.tugas;
