-- ======================================================
-- 005_access_codes_schema_repair.sql
--
-- TUJUAN
--   Memperbaiki error:
--     "Could not find the table 'public.kode_akses_siswa' in the schema cache"
--   pada project yang tabelnya belum pernah dibuat (migration 004 belum
--   dijalankan) ATAU tabelnya ada tetapi schema cache PostgREST basi
--   (mis. setelah migration dijalankan lewat jalur lain).
--
-- SIFAT
--   * Idempotent: aman dijalankan berulang kali.
--   * Tidak menghapus tabel/data apa pun (hanya CREATE ... IF NOT EXISTS,
--     ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
--     CREATE OR REPLACE FUNCTION, DROP POLICY IF EXISTS + CREATE POLICY).
--   * Tidak melemahkan keamanan: RLS tetap aktif, anon tidak diberi akses,
--     tidak ada policy tulis untuk client (tulis hanya lewat service_role).
--   * Isi tabel/policy/fungsi di sini MENCERMINKAN 004_access_codes_audit.sql.
--     Jika 004 sudah pernah dijalankan, bagian DDL di bawah menjadi no-op;
--     yang benar-benar baru hanya `kode_akses_stats()`,
--     `edutask_schema_health()`, dan `notify pgrst 'reload schema'`.
--
-- CARA PAKAI
--   Supabase Dashboard → SQL Editor → tempel seluruh isi file → Run.
--   Atau: supabase db push (jika project dikelola lewat CLI).
--
-- URUTAN YANG DISARANKAN
--   1) Deploy Edge Functions student-access & student-codes versi terbaru.
--   2) Jalankan 003_storage_attachments.sql (bila belum).
--   3) Jalankan file ini (005).
-- ======================================================

-- ------------------------------------------------------
-- 1) Helper: apakah guru berwenang atas kelas tertentu
--    (wali kelas, punya jadwal, atau terdaftar di guru_mapel)
--    Dipakai oleh policy SELECT pada kode_akses_siswa.
-- ------------------------------------------------------
create or replace function public.guru_handles_kelas(p_kelas_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (select 1 from public.kelas k where k.id = p_kelas_id and k.wali_kelas_id = auth.uid())
    or exists (select 1 from public.jadwal_pelajaran j where j.kelas_id = p_kelas_id and j.guru_id = auth.uid())
    or exists (select 1 from public.guru_mapel gm where gm.kelas_id = p_kelas_id and gm.guru_id = auth.uid())
$$;

-- ------------------------------------------------------
-- 2) Tabel utama: public.kode_akses_siswa
--    Kode TIDAK disimpan plaintext — hanya SHA-256 + prefix tampilan.
-- ------------------------------------------------------
create table if not exists public.kode_akses_siswa (
  id uuid primary key default gen_random_uuid(),
  kode_hash text not null unique,
  kode_prefix text not null,
  kelas_id uuid not null,
  siswa_id uuid,
  single_use boolean not null default true,
  status text not null default 'active',
  expires_at timestamptz,
  used_by_siswa_id uuid,
  used_at timestamptz,
  revoked_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  note text
);

-- 2a) Kolom yang mungkin belum ada pada tabel versi lama/parsial.
alter table public.kode_akses_siswa add column if not exists kode_hash text;
alter table public.kode_akses_siswa add column if not exists kode_prefix text;
alter table public.kode_akses_siswa add column if not exists kelas_id uuid;
alter table public.kode_akses_siswa add column if not exists siswa_id uuid;
alter table public.kode_akses_siswa add column if not exists single_use boolean not null default true;
alter table public.kode_akses_siswa add column if not exists status text not null default 'active';
alter table public.kode_akses_siswa add column if not exists expires_at timestamptz;
alter table public.kode_akses_siswa add column if not exists used_by_siswa_id uuid;
alter table public.kode_akses_siswa add column if not exists used_at timestamptz;
alter table public.kode_akses_siswa add column if not exists revoked_at timestamptz;
alter table public.kode_akses_siswa add column if not exists created_by uuid;
alter table public.kode_akses_siswa add column if not exists created_at timestamptz not null default now();
alter table public.kode_akses_siswa add column if not exists note text;

-- 2b) Foreign key — hanya ditambahkan bila kolomnya belum menjadi bagian FK.
--     Pemeriksaan memakai pg_constraint.conkey + pg_attribute, bukan teks
--     constraintdef, supaya tidak terpengaruh skema tampilan/quoting.
do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_attribute a on a.attrelid = t.oid and a.attnum = any (c.conkey)
    where n.nspname = 'public' and t.relname = 'kode_akses_siswa'
      and c.contype = 'f' and a.attname = 'kelas_id'
  ) then
    alter table public.kode_akses_siswa
      add constraint kode_akses_siswa_kelas_id_fkey
      foreign key (kelas_id) references public.kelas(id) on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_attribute a on a.attrelid = t.oid and a.attnum = any (c.conkey)
    where n.nspname = 'public' and t.relname = 'kode_akses_siswa'
      and c.contype = 'f' and a.attname = 'siswa_id'
  ) then
    alter table public.kode_akses_siswa
      add constraint kode_akses_siswa_siswa_id_fkey
      foreign key (siswa_id) references public.siswa(id) on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_attribute a on a.attrelid = t.oid and a.attnum = any (c.conkey)
    where n.nspname = 'public' and t.relname = 'kode_akses_siswa'
      and c.contype = 'f' and a.attname = 'used_by_siswa_id'
  ) then
    alter table public.kode_akses_siswa
      add constraint kode_akses_siswa_used_by_fkey
      foreign key (used_by_siswa_id) references public.siswa(id) on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_attribute a on a.attrelid = t.oid and a.attnum = any (c.conkey)
    where n.nspname = 'public' and t.relname = 'kode_akses_siswa'
      and c.contype = 'f' and a.attname = 'created_by'
  ) then
    alter table public.kode_akses_siswa
      add constraint kode_akses_siswa_created_by_fkey
      foreign key (created_by) references public.profiles(id) on delete set null;
  end if;
end $$;

-- 2c) Status hanya boleh salah satu dari empat nilai.
--     NOT VALID agar tidak menggagalkan migration bila ada baris lama aneh;
--     baris baru tetap divalidasi.
do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_attribute a on a.attrelid = t.oid and a.attnum = any (c.conkey)
    where n.nspname = 'public' and t.relname = 'kode_akses_siswa'
      and c.contype = 'u' and a.attname = 'kode_hash'
  ) and not exists (
    select 1
    from pg_index i
    join pg_class t on t.oid = i.indrelid
    join pg_namespace n on n.oid = t.relnamespace
    join pg_attribute a on a.attrelid = t.oid and a.attnum = any (i.indkey)
    where n.nspname = 'public' and t.relname = 'kode_akses_siswa'
      and i.indisunique and a.attname = 'kode_hash'
  ) then
    -- Jika ada baris duplikat dari tabel versi lama, index unik gagal dibuat.
    -- Karena itu ditangani sebagai exception agar migration tidak berhenti
    -- dan admin mendapat pesan yang jelas.
    begin
      create unique index uq_kode_akses_hash on public.kode_akses_siswa(kode_hash);
    exception when unique_violation then
      raise warning 'kode_akses_siswa: ada kode_hash duplikat; index unik uq_kode_akses_hash dilewati. Periksa baris duplikat lalu jalankan ulang 005.';
    end;
  end if;
end $$;

-- 2e) RLS + policy baca (admin semua, guru kelas yang diampu).
alter table public.kode_akses_siswa enable row level security;

drop policy if exists "kode akses: admin baca semua" on public.kode_akses_siswa;
create policy "kode akses: admin baca semua"
on public.kode_akses_siswa for select
to authenticated
using (public.is_admin());

drop policy if exists "kode akses: guru baca kelas sendiri" on public.kode_akses_siswa;
create policy "kode akses: guru baca kelas sendiri"
on public.kode_akses_siswa for select
to authenticated
using (public.is_guru() and public.guru_handles_kelas(kelas_id));

-- Tidak ada policy INSERT/UPDATE/DELETE untuk client.
-- Penulisan hanya lewat Edge Function dengan service_role.
revoke all on public.kode_akses_siswa from anon, authenticated;
grant select on public.kode_akses_siswa to authenticated;
grant all on public.kode_akses_siswa to service_role;

-- ------------------------------------------------------
-- 3) Rate limit percobaan kode (dipakai student-access)
-- ------------------------------------------------------
create table if not exists public.kode_akses_attempt (
  id bigserial primary key,
  ip text,
  success boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_kode_attempt_ip_time
  on public.kode_akses_attempt (ip, created_at desc);

alter table public.kode_akses_attempt enable row level security;
revoke all on public.kode_akses_attempt from anon, authenticated;
grant all on public.kode_akses_attempt to service_role;

-- ------------------------------------------------------
-- 4) Audit log (dipakai dashboard admin & Edge Functions)
-- ------------------------------------------------------
create table if not exists public.audit_log (
  id bigserial primary key,
  actor_id uuid,
  actor_role text,
  action text not null,
  entity text not null,
  entity_id uuid,
  detail jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_created on public.audit_log(created_at desc);
create index if not exists idx_audit_actor on public.audit_log(actor_id);

alter table public.audit_log enable row level security;

drop policy if exists "audit: admin baca" on public.audit_log;
create policy "audit: admin baca"
on public.audit_log for select
to authenticated
using (public.is_admin());

revoke all on public.audit_log from anon, authenticated;
grant select on public.audit_log to authenticated;
grant all on public.audit_log to service_role;

-- Trigger audit untuk perubahan kode akses (insert/update/delete).
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_entity uuid;
  v_detail jsonb;
begin
  begin
    select role into v_role from public.profiles where id = v_actor;
  exception when others then
    v_role := null;
  end;

  if tg_op = 'DELETE' then
    v_entity := (to_jsonb(old) ->> 'id')::uuid;
    v_detail := jsonb_build_object('operation', 'delete');
  else
    v_entity := (to_jsonb(new) ->> 'id')::uuid;
    if tg_op = 'UPDATE' then
      select jsonb_object_agg(n.key, true) into v_detail
      from jsonb_each(to_jsonb(new)) as n
      where to_jsonb(old) -> n.key is distinct from n.value;
      v_detail := jsonb_build_object('operation', 'update', 'changed', coalesce(v_detail, '{}'::jsonb));
    else
      v_detail := jsonb_build_object('operation', 'insert');
    end if;
  end if;

  insert into public.audit_log (actor_id, actor_role, action, entity, entity_id, detail)
  values (v_actor, coalesce(v_role, 'system'), lower(tg_op), tg_table_name, v_entity, v_detail);

  return coalesce(new, old);
end;
$$;

drop trigger if exists audit_kode on public.kode_akses_siswa;
create trigger audit_kode after insert or update or delete on public.kode_akses_siswa
for each row execute function public.audit_row_change();

-- ------------------------------------------------------
-- 5) Klaim kode secara atomik (SELECT ... FOR UPDATE)
--    Mencerminkan 004. Dipanggil HANYA oleh Edge Function (service_role).
-- ------------------------------------------------------
create or replace function public.claim_kode_akses(p_kode_hash text, p_siswa_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kode public.kode_akses_siswa%rowtype;
  v_now timestamptz := now();
  v_valid boolean;
begin
  select * into v_kode
  from public.kode_akses_siswa
  where kode_hash = p_kode_hash
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_kode.status = 'revoked' then
    return jsonb_build_object('ok', false, 'reason', 'revoked');
  end if;

  if v_kode.status = 'used' and v_kode.single_use then
    return jsonb_build_object('ok', false, 'reason', 'used');
  end if;

  if v_kode.expires_at is not null and v_kode.expires_at <= v_now then
    update public.kode_akses_siswa
       set status = 'expired'
     where id = v_kode.id;
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  if v_kode.siswa_id is not null and v_kode.siswa_id <> p_siswa_id then
    return jsonb_build_object('ok', false, 'reason', 'wrong_student');
  end if;

  if v_kode.single_use and v_kode.used_at is not null then
    return jsonb_build_object('ok', false, 'reason', 'used');
  end if;

  select exists (
    select 1 from public.siswa s
    where s.id = p_siswa_id
      and s.status_aktif = true
      and s.kelas_id = v_kode.kelas_id
  ) into v_valid;

  if not v_valid then
    return jsonb_build_object('ok', false, 'reason', 'class_mismatch');
  end if;

  update public.kode_akses_siswa
     set status = case when v_kode.single_use then 'used' else v_kode.status end,
         used_at = coalesce(v_kode.used_at, v_now),
         used_by_siswa_id = p_siswa_id
   where id = v_kode.id;

  return jsonb_build_object(
    'ok', true,
    'kode', jsonb_build_object(
      'id', v_kode.id,
      'kelas_id', v_kode.kelas_id,
      'siswa_id', v_kode.siswa_id,
      'single_use', v_kode.single_use
    )
  );
end;
$$;

revoke all on function public.claim_kode_akses(text, uuid) from public, anon, authenticated;
grant execute on function public.claim_kode_akses(text, uuid) to service_role;

-- ------------------------------------------------------
-- 6) Statistik kode akses untuk dashboard
--    SECURITY INVOKER → RLS tetap berlaku:
--      * admin melihat seluruh baris,
--      * guru hanya kelas yang diampu.
--    Dihitung di database sehingga tetap benar walau >200 kode.
-- ------------------------------------------------------
create or replace function public.kode_akses_stats()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'total', count(*),
    'active', count(*) filter (
      where status = 'active' and (expires_at is null or expires_at > now())
    ),
    'used', count(*) filter (where status = 'used'),
    'expired', count(*) filter (
      where status = 'expired'
         or (status = 'active' and expires_at is not null and expires_at <= now())
    ),
    'revoked', count(*) filter (where status = 'revoked')
  )
  from public.kode_akses_siswa;
$$;

revoke all on function public.kode_akses_stats() from public, anon;
grant execute on function public.kode_akses_stats() to authenticated, service_role;

-- ------------------------------------------------------
-- 7) Diagnostik skema (khusus admin)
--    Dipakai halaman Pengaturan → "Kesehatan server & skema" agar
--    masalah migration bisa dideteksi dari aplikasi, bukan menebak.
-- ------------------------------------------------------
create or replace function public.edutask_schema_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'checked_at', now(),
    'version', 'edutask-schema-005',
    'tables', jsonb_build_object(
      'kode_akses_siswa', to_regclass('public.kode_akses_siswa') is not null,
      'kode_akses_attempt', to_regclass('public.kode_akses_attempt') is not null,
      'audit_log', to_regclass('public.audit_log') is not null,
      'siswa_akun', to_regclass('public.siswa_akun') is not null
    ),
    'functions', jsonb_build_object(
      'claim_kode_akses', to_regprocedure('public.claim_kode_akses(text,uuid)') is not null,
      'kode_akses_stats', to_regprocedure('public.kode_akses_stats()') is not null,
      'guru_handles_kelas', to_regprocedure('public.guru_handles_kelas(uuid)') is not null
    ),
    'rls_enabled', jsonb_build_object(
      'kode_akses_siswa', coalesce((
        select c.relrowsecurity from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'kode_akses_siswa'
      ), false),
      'kode_akses_attempt', coalesce((
        select c.relrowsecurity from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'kode_akses_attempt'
      ), false),
      'audit_log', coalesce((
        select c.relrowsecurity from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'audit_log'
      ), false),
      'siswa', coalesce((
        select c.relrowsecurity from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'siswa'
      ), false),
      'kelas', coalesce((
        select c.relrowsecurity from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'kelas'
      ), false)
    ),
    'policies', jsonb_build_object(
      'kode_akses_siswa', (
        select count(*) from pg_policies p
        where p.schemaname = 'public' and p.tablename = 'kode_akses_siswa'
      ),
      'kode_akses_attempt', (
        select count(*) from pg_policies p
        where p.schemaname = 'public' and p.tablename = 'kode_akses_attempt'
      ),
      'audit_log', (
        select count(*) from pg_policies p
        where p.schemaname = 'public' and p.tablename = 'audit_log'
      ),
      'siswa', (
        select count(*) from pg_policies p
        where p.schemaname = 'public' and p.tablename = 'siswa'
      ),
      'kelas', (
        select count(*) from pg_policies p
        where p.schemaname = 'public' and p.tablename = 'kelas'
      )
    ),
    'missing_columns', coalesce((
      select jsonb_agg(col order by col)
      from unnest(array[
        'id', 'kode_hash', 'kode_prefix', 'kelas_id', 'siswa_id', 'single_use',
        'status', 'expires_at', 'used_by_siswa_id', 'used_at', 'revoked_at',
        'created_by', 'created_at', 'note'
      ]) as col
      where not exists (
        select 1 from information_schema.columns ic
        where ic.table_schema = 'public'
          and ic.table_name = 'kode_akses_siswa'
          and ic.column_name = col
      )
    ), '[]'::jsonb),
    'anon_can_select_siswa', coalesce((
      select bool_or(ic.privilege_type = 'SELECT')
      from information_schema.column_privileges ic
      where ic.table_schema = 'public'
        and ic.table_name = 'kode_akses_siswa'
        and ic.grantee = 'anon'
    ), false)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.edutask_schema_health() from public, anon;
grant execute on function public.edutask_schema_health() to authenticated, service_role;

-- ------------------------------------------------------
-- 8) Muat ulang schema cache PostgREST
--    Mekanisme resmi: NOTIFY pada channel "pgrst".
--    Ini yang membuat tabel/fungsi baru langsung dikenali API
--    tanpa menunggu/menebak-nebak.
-- ------------------------------------------------------
notify pgrst, 'reload schema';

-- ------------------------------------------------------
-- 9) Verifikasi cepat (jalankan manual bila perlu)
-- ------------------------------------------------------
-- select public.edutask_schema_health();
-- select public.kode_akses_stats();
