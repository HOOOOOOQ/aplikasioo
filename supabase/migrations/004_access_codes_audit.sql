-- ======================================================
-- 004_access_codes_audit.sql
-- Sistem kode akses siswa (server-generated, server-verified, atomic)
-- + audit log aktivitas admin/guru.
--
-- Jalankan SETELAH 001, 002, 003 dan SETELAH Edge Function
-- `student-access` + `student-codes` di-deploy.
--
-- Prinsip keamanan:
--  * Kode TIDAK disimpan sebagai plaintext. Yang disimpan hanya SHA-256
--    (kode_hash) dan 6 karakter pertama untuk ditampilkan di dashboard.
--  * Pembuatan kode hanya lewat Edge Function (service_role), tidak dari client.
--  * Klaim kode dilakukan dalam satu transaksi (SELECT ... FOR UPDATE) agar dua
--    akun tidak bisa memakai kode sekali-pakai secara bersamaan.
--  * Client tidak boleh INSERT/UPDATE/DELETE tabel ini.
-- Idempotent: aman dijalankan berulang.
-- ======================================================

-- ------------------------------------------------------
-- 1) Helper: apakah guru berwenang atas kelas tertentu
--    (wali kelas, punya jadwal, atau terdaftar di guru_mapel)
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
-- 2) Tabel kode akses siswa
-- ------------------------------------------------------
create table if not exists public.kode_akses_siswa (
  id uuid primary key default gen_random_uuid(),
  kode_hash text not null unique,
  kode_prefix text not null,
  kelas_id uuid not null references public.kelas(id) on delete cascade,
  siswa_id uuid references public.siswa(id) on delete cascade,
  single_use boolean not null default true,
  status text not null default 'active' check (status in ('active', 'used', 'revoked', 'expired')),
  expires_at timestamptz,
  used_by_siswa_id uuid references public.siswa(id) on delete set null,
  used_at timestamptz,
  revoked_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  note text
);

create index if not exists idx_kode_akses_kelas on public.kode_akses_siswa(kelas_id);
create index if not exists idx_kode_akses_siswa on public.kode_akses_siswa(siswa_id);
create index if not exists idx_kode_akses_status on public.kode_akses_siswa(status);
create index if not exists idx_kode_akses_created on public.kode_akses_siswa(created_at desc);

alter table public.kode_akses_siswa enable row level security;

drop policy if exists "kode akses: admin baca semua" on public.kode_akses_siswa;
drop policy if exists "kode akses: guru baca kelas sendiri" on public.kode_akses_siswa;

create policy "kode akses: admin baca semua"
on public.kode_akses_siswa for select
to authenticated
using (public.is_admin());

create policy "kode akses: guru baca kelas sendiri"
on public.kode_akses_siswa for select
to authenticated
using (public.is_guru() and public.guru_handles_kelas(kelas_id));

-- Tidak ada policy INSERT/UPDATE/DELETE → hanya service_role (Edge Function)
-- yang bisa menulis. Ini mencegah guru/admin membuat kode lemah dari client.
revoke all on public.kode_akses_siswa from anon;
grant select on public.kode_akses_siswa to authenticated;

-- ------------------------------------------------------
-- 3) Tautan akun auth siswa ↔ data siswa (opsional, untuk siswa yang punya akun)
-- ------------------------------------------------------
create table if not exists public.siswa_akun (
  user_id uuid primary key references auth.users(id) on delete cascade,
  siswa_id uuid not null unique references public.siswa(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.siswa_akun enable row level security;

drop policy if exists "siswa akun: baca sendiri atau admin" on public.siswa_akun;
create policy "siswa akun: baca sendiri atau admin"
on public.siswa_akun for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

revoke all on public.siswa_akun from anon;

-- ------------------------------------------------------
-- 4) Rate limit percobaan kode (anti brute force)
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

-- ------------------------------------------------------
-- 5) Audit log aktivitas
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

revoke all on public.audit_log from anon;
grant select on public.audit_log to authenticated;

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

drop trigger if exists audit_profiles on public.profiles;
create trigger audit_profiles after insert or update or delete on public.profiles
for each row execute function public.audit_row_change();

drop trigger if exists audit_kelas on public.kelas;
create trigger audit_kelas after insert or update or delete on public.kelas
for each row execute function public.audit_row_change();

drop trigger if exists audit_siswa on public.siswa;
create trigger audit_siswa after insert or update or delete on public.siswa
for each row execute function public.audit_row_change();

drop trigger if exists audit_mapel on public.mata_pelajaran;
create trigger audit_mapel after insert or update or delete on public.mata_pelajaran
for each row execute function public.audit_row_change();

drop trigger if exists audit_jadwal on public.jadwal_pelajaran;
create trigger audit_jadwal after insert or update or delete on public.jadwal_pelajaran
for each row execute function public.audit_row_change();

drop trigger if exists audit_tugas on public.tugas;
create trigger audit_tugas after insert or update or delete on public.tugas
for each row execute function public.audit_row_change();

drop trigger if exists audit_kode on public.kode_akses_siswa;
create trigger audit_kode after insert or update or delete on public.kode_akses_siswa
for each row execute function public.audit_row_change();

-- ------------------------------------------------------
-- 6) Klaim kode secara atomik
--    Dipanggil HANYA oleh Edge Function (service_role).
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
-- 7) Cek cepat
-- ------------------------------------------------------
-- select kelas_id, status, count(*) from public.kode_akses_siswa group by 1,2;
-- select entity, action, count(*) from public.audit_log group by 1,2 order by 3 desc;
