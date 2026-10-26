-- ======================================================
-- 006_round4_academic_chat.sql
--
-- TUJUAN
--   Fondasi fitur baru ronde 4 TANPA mengubah/menghapus data lama:
--     * idempotency penerbitan kode akses (anti kode ganda saat retry),
--     * pengumuman sekolah,
--     * kalender akademik & agenda,
--     * pengumpulan tugas + revisi + umpan balik guru,
--     * diskusi tugas per kelas,
--     * chat privat / grup kelas / diskusi tugas,
--     * pusat notifikasi,
--     * fungsi bantu: pencarian global, statistik akademik, unread chat,
--     * edutask_schema_health() versi 006.
--
-- SIFAT
--   * Idempotent: aman dijalankan berulang.
--   * Non-destruktif: hanya CREATE ... IF NOT EXISTS, ADD COLUMN IF NOT EXISTS,
--     CREATE INDEX IF NOT EXISTS, DROP POLICY IF EXISTS + CREATE POLICY.
--   * RLS aktif di SEMUA tabel baru. Peran `anon` hanya diberi akses baca
--     untuk data yang memang publik bagi siswa (pengumuman & kalender
--     terbit). Chat, pengumpulan, diskusi, dan notifikasi privat TIDAK
--     dapat dibaca anon; jalur siswa memakai Edge Function bertoken HMAC.
--   * Tidak ada service_role di aplikasi.
-- ======================================================

-- ------------------------------------------------------
-- 0) Idempotency penerbitan kode akses
--    Admin yang menekan "Buat kode" berulang (atau retry setelah timeout)
--    tidak boleh menghasilkan dua kode. Client mengirim idempotency_key
--    (uuid v4); unique index memastikan hanya satu baris per key.
-- ------------------------------------------------------
alter table public.kode_akses_siswa
  add column if not exists idempotency_key text;

update public.kode_akses_siswa
   set idempotency_key = null
 where idempotency_key = '';

create unique index if not exists uq_kode_akses_idempotency
  on public.kode_akses_siswa(idempotency_key)
  where idempotency_key is not null;

-- Riwayat aksi kode akses (terbit/cabut/verifikasi/klaim) dibaca di halaman
-- "Riwayat kode". Audit log tetap menjadi sumber utama; view ini memudahkan
-- query per kode tanpa memindai seluruh audit_log.
create or replace function public.kode_akses_riwayat(p_limit integer default 50)
returns table (
  id uuid,
  kode_prefix text,
  kelas_id uuid,
  siswa_id uuid,
  status text,
  created_at timestamptz,
  expires_at timestamptz,
  used_at timestamptz,
  used_by_siswa_id uuid,
  revoked_at timestamptz,
  created_by uuid,
  note text
)
language sql
stable
security invoker
set search_path = public
as $$
  select k.id, k.kode_prefix, k.kelas_id, k.siswa_id, k.status, k.created_at,
         k.expires_at, k.used_at, k.used_by_siswa_id, k.revoked_at,
         k.created_by, k.note
    from public.kode_akses_siswa k
   order by k.created_at desc
   limit greatest(1, least(coalesce(p_limit, 50), 500));
$$;

revoke all on function public.kode_akses_riwayat(integer) from public, anon;
grant execute on function public.kode_akses_riwayat(integer) to authenticated, service_role;

-- ------------------------------------------------------
-- 1) PENGUMUMAN SEKOLAH
-- ------------------------------------------------------
create table if not exists public.pengumuman (
  id uuid primary key default gen_random_uuid(),
  judul text not null check (char_length(judul) between 3 and 160),
  isi text not null check (char_length(isi) between 3 and 5000),
  target text not null default 'semua' check (target in ('semua','guru','siswa')),
  kelas_id uuid references public.kelas(id) on delete cascade,
  is_published boolean not null default true,
  publish_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_pengumuman_publish on public.pengumuman(publish_at desc);
create index if not exists idx_pengumuman_kelas on public.pengumuman(kelas_id);

drop trigger if exists set_pengumuman_updated_at on public.pengumuman;
create trigger set_pengumuman_updated_at before update on public.pengumuman
for each row execute function public.handle_updated_at();

alter table public.pengumuman enable row level security;

drop policy if exists "pengumuman: publik baca terbit" on public.pengumuman;
create policy "pengumuman: publik baca terbit"
on public.pengumuman for select
to anon, authenticated
using (
  is_published = true
  and publish_at <= now()
  and (kelas_id is null or public.is_admin() or public.guru_handles_kelas(kelas_id))
);

drop policy if exists "pengumuman: admin kelola" on public.pengumuman;
create policy "pengumuman: admin kelola"
on public.pengumuman for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "pengumuman: guru kelola kelas sendiri" on public.pengumuman;
create policy "pengumuman: guru kelola kelas sendiri"
on public.pengumuman for all
to authenticated
using (public.is_guru() and kelas_id is not null and public.guru_handles_kelas(kelas_id))
with check (public.is_guru() and kelas_id is not null and public.guru_handles_kelas(kelas_id));

revoke all on public.pengumuman from anon, authenticated;
grant select on public.pengumuman to anon, authenticated;
grant insert, update, delete on public.pengumuman to authenticated;
grant all on public.pengumuman to service_role;

-- ------------------------------------------------------
-- 2) KALENDER AKADEMIK & AGENDA
-- ------------------------------------------------------
create table if not exists public.kalender_akademik (
  id uuid primary key default gen_random_uuid(),
  judul text not null check (char_length(judul) between 3 and 160),
  deskripsi text,
  tipe text not null default 'kegiatan'
    check (tipe in ('libur','ujian','kegiatan','rapat','lainnya')),
  tanggal_mulai date not null,
  tanggal_selesai date,
  kelas_id uuid references public.kelas(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint kalender_tanggal_valid check (tanggal_selesai is null or tanggal_selesai >= tanggal_mulai)
);

create index if not exists idx_kalender_tanggal on public.kalender_akademik(tanggal_mulai);

drop trigger if exists set_kalender_updated_at on public.kalender_akademik;
create trigger set_kalender_updated_at before update on public.kalender_akademik
for each row execute function public.handle_updated_at();

alter table public.kalender_akademik enable row level security;

drop policy if exists "kalender: publik baca" on public.kalender_akademik;
create policy "kalender: publik baca"
on public.kalender_akademik for select
to anon, authenticated
using (kelas_id is null or public.is_admin() or public.guru_handles_kelas(kelas_id));

drop policy if exists "kalender: admin kelola" on public.kalender_akademik;
create policy "kalender: admin kelola"
on public.kalender_akademik for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

revoke all on public.kalender_akademik from anon, authenticated;
grant select on public.kalender_akademik to anon, authenticated;
grant insert, update, delete on public.kalender_akademik to authenticated;
grant all on public.kalender_akademik to service_role;

-- ------------------------------------------------------
-- 3) PENGUMPULAN TUGAS + REVISI + UMPAN BALIK
--    Ditulis siswa lewat Edge Function `student-portal` (service_role,
--    token HMAC siswa). Guru/admin menilai lewat RLS di bawah.
-- ------------------------------------------------------
create table if not exists public.tugas_pengumpulan (
  id uuid primary key default gen_random_uuid(),
  tugas_id uuid not null references public.tugas(id) on delete cascade,
  siswa_id uuid not null references public.siswa(id) on delete cascade,
  revisi_ke integer not null default 1 check (revisi_ke between 1 and 20),
  jawaban_teks text check (jawaban_teks is null or char_length(jawaban_teks) <= 8000),
  lampiran_path text,
  status text not null default 'terkirim'
    check (status in ('draft','terkirim','dinilai','revisi')),
  nilai numeric(5,2) check (nilai is null or (nilai >= 0 and nilai <= 100)),
  umpan_balik text,
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tugas_id, siswa_id, revisi_ke)
);

create index if not exists idx_pengumpulan_tugas on public.tugas_pengumpulan(tugas_id);
create index if not exists idx_pengumpulan_siswa on public.tugas_pengumpulan(siswa_id);
create index if not exists idx_pengumpulan_status on public.tugas_pengumpulan(status);

drop trigger if exists set_pengumpulan_updated_at on public.tugas_pengumpulan;
create trigger set_pengumpulan_updated_at before update on public.tugas_pengumpulan
for each row execute function public.handle_updated_at();

alter table public.tugas_pengumpulan enable row level security;

-- Guru melihat/menilai pengumpulan pada tugas di kelas yang diampu; admin semua.
create or replace function public.guru_handles_tugas(p_tugas_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.tugas t
    where t.id = p_tugas_id
      and (t.guru_id = auth.uid() or public.guru_handles_kelas(t.kelas_id))
  );
$$;

drop policy if exists "pengumpulan: guru baca" on public.tugas_pengumpulan;
create policy "pengumpulan: guru baca"
on public.tugas_pengumpulan for select
to authenticated
using (public.is_admin() or public.guru_handles_tugas(tugas_id));

drop policy if exists "pengumpulan: guru nilai" on public.tugas_pengumpulan;
create policy "pengumpulan: guru nilai"
on public.tugas_pengumpulan for update
to authenticated
using (public.is_admin() or public.guru_handles_tugas(tugas_id))
with check (public.is_admin() or public.guru_handles_tugas(tugas_id));

revoke all on public.tugas_pengumpulan from anon, authenticated;
grant select, update on public.tugas_pengumpulan to authenticated;
grant all on public.tugas_pengumpulan to service_role;

-- ------------------------------------------------------
-- 4) DISKUSI TUGAS (komentar per tugas/kelas)
-- ------------------------------------------------------
create table if not exists public.tugas_komentar (
  id uuid primary key default gen_random_uuid(),
  tugas_id uuid not null references public.tugas(id) on delete cascade,
  author_role text not null check (author_role in ('admin','guru','siswa')),
  author_profile_id uuid references public.profiles(id) on delete set null,
  author_siswa_id uuid references public.siswa(id) on delete set null,
  author_nama text not null,
  isi text not null check (char_length(isi) between 1 and 1500),
  created_at timestamptz not null default now(),
  constraint komentar_author_valid check (
    (author_role = 'siswa' and author_siswa_id is not null)
    or (author_role in ('admin','guru') and author_profile_id is not null)
  )
);

create index if not exists idx_komentar_tugas on public.tugas_komentar(tugas_id, created_at);

alter table public.tugas_komentar enable row level security;

drop policy if exists "komentar: guru baca" on public.tugas_komentar;
create policy "komentar: guru baca"
on public.tugas_komentar for select
to authenticated
using (public.is_admin() or public.guru_handles_tugas(tugas_id));

drop policy if exists "komentar: guru tulis" on public.tugas_komentar;
create policy "komentar: guru tulis"
on public.tugas_komentar for insert
to authenticated
with check (
  author_profile_id = auth.uid()
  and author_role in ('admin','guru')
  and (public.is_admin() or public.guru_handles_tugas(tugas_id))
);

drop policy if exists "komentar: penulis hapus" on public.tugas_komentar;
create policy "komentar: penulis hapus"
on public.tugas_komentar for delete
to authenticated
using (author_profile_id = auth.uid() or public.is_admin());

revoke all on public.tugas_komentar from anon, authenticated;
grant select, insert, delete on public.tugas_komentar to authenticated;
grant all on public.tugas_komentar to service_role;

-- ------------------------------------------------------
-- 5) CHAT: thread, anggota, pesan
--    * Guru/admin memakai client Supabase langsung (RLS).
--    * Siswa memakai Edge Function `student-chat` (token HMAC).
-- ------------------------------------------------------
create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  tipe text not null check (tipe in ('direct','kelas','tugas')),
  judul text,
  kelas_id uuid references public.kelas(id) on delete cascade,
  tugas_id uuid references public.tugas(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);

create index if not exists idx_chat_threads_last on public.chat_threads(last_message_at desc);
create index if not exists idx_chat_threads_kelas on public.chat_threads(kelas_id);

-- Satu thread per kelas & satu thread diskusi per tugas.
create unique index if not exists uq_chat_thread_kelas
  on public.chat_threads(kelas_id) where tipe = 'kelas';
create unique index if not exists uq_chat_thread_tugas
  on public.chat_threads(tugas_id) where tipe = 'tugas';

create table if not exists public.chat_members (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  siswa_id uuid references public.siswa(id) on delete cascade,
  peran text not null default 'anggota' check (peran in ('anggota','pengelola')),
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  constraint chat_member_subject check (
    (profile_id is not null and siswa_id is null) or (profile_id is null and siswa_id is not null)
  )
);

create unique index if not exists uq_chat_member_profile
  on public.chat_members(thread_id, profile_id) where profile_id is not null;
create unique index if not exists uq_chat_member_siswa
  on public.chat_members(thread_id, siswa_id) where siswa_id is not null;

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_profile_id uuid references public.profiles(id) on delete set null,
  sender_siswa_id uuid references public.siswa(id) on delete set null,
  sender_nama text not null,
  body text not null check (char_length(body) between 1 and 2000),
  client_id text check (client_id is null or char_length(client_id) <= 64),
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_messages_thread on public.chat_messages(thread_id, created_at desc);
create unique index if not exists uq_chat_message_client
  on public.chat_messages(thread_id, client_id) where client_id is not null;

-- Helper: anggota thread untuk user login saat ini.
create or replace function public.is_chat_member(p_thread uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chat_members m
    where m.thread_id = p_thread and m.profile_id = auth.uid()
  );
$$;

-- Helper: boleh mengelola (membaca/menulis) thread institusional kelas/tugas.
-- Thread `direct` TIDAK otomatis terbuka untuk admin.
create or replace function public.can_access_thread(p_thread uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chat_threads t
    where t.id = p_thread
      and (
        exists (
          select 1 from public.chat_members m
          where m.thread_id = t.id and m.profile_id = auth.uid()
        )
        or (
          t.tipe in ('kelas','tugas')
          and t.kelas_id is not null
          and (public.is_admin() or public.guru_handles_kelas(t.kelas_id))
        )
      )
  );
$$;

alter table public.chat_threads enable row level security;
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists "chat thread: anggota baca" on public.chat_threads;
create policy "chat thread: anggota baca"
on public.chat_threads for select
to authenticated
using (public.can_access_thread(id));

drop policy if exists "chat thread: guru buat" on public.chat_threads;
create policy "chat thread: guru buat"
on public.chat_threads for insert
to authenticated
with check (
  created_by = auth.uid()
  and (
    public.is_admin()
    or (public.is_guru() and kelas_id is not null and public.guru_handles_kelas(kelas_id))
  )
);

drop policy if exists "chat thread: pengelola ubah" on public.chat_threads;
create policy "chat thread: pengelola ubah"
on public.chat_threads for update
to authenticated
using (public.can_access_thread(id) and (public.is_admin() or public.is_guru()))
with check (public.can_access_thread(id));

drop policy if exists "chat member: diri sendiri baca" on public.chat_members;
create policy "chat member: diri sendiri baca"
on public.chat_members for select
to authenticated
using (profile_id = auth.uid() or public.can_access_thread(thread_id));

drop policy if exists "chat member: guru kelola" on public.chat_members;
create policy "chat member: guru kelola"
on public.chat_members for all
to authenticated
using (public.is_admin() or public.can_access_thread(thread_id))
with check (
  public.is_admin()
  or exists (
    select 1 from public.chat_threads t
    where t.id = thread_id
      and t.tipe in ('kelas','tugas')
      and t.kelas_id is not null
      and public.guru_handles_kelas(t.kelas_id)
  )
);

drop policy if exists "chat message: anggota baca" on public.chat_messages;
create policy "chat message: anggota baca"
on public.chat_messages for select
to authenticated
using (public.can_access_thread(thread_id));

drop policy if exists "chat message: anggota kirim" on public.chat_messages;
create policy "chat message: anggota kirim"
on public.chat_messages for insert
to authenticated
with check (
  sender_profile_id = auth.uid()
  and sender_siswa_id is null
  and public.can_access_thread(thread_id)
);

revoke all on public.chat_threads from anon, authenticated;
revoke all on public.chat_members from anon, authenticated;
revoke all on public.chat_messages from anon, authenticated;

grant select, insert, update on public.chat_threads to authenticated;
grant select, insert, update, delete on public.chat_members to authenticated;
grant select, insert on public.chat_messages to authenticated;
grant all on public.chat_threads to service_role;
grant all on public.chat_members to service_role;
grant all on public.chat_messages to service_role;

-- Update last_message_at otomatis (dipakai untuk urutan daftar percakapan).
create or replace function public.touch_chat_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_threads
     set last_message_at = new.created_at
   where id = new.thread_id;
  return new;
end;
$$;

drop trigger if exists trg_touch_chat_thread on public.chat_messages;
create trigger trg_touch_chat_thread after insert on public.chat_messages
for each row execute function public.touch_chat_thread();

-- Realtime: kirim pesan baru ke client yang berhak (RLS tetap berlaku).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.chat_messages;
    exception when duplicate_object then
      null; -- sudah terdaftar
    end;
  end if;
end $$;

-- Jumlah pesan belum dibaca untuk user login saat ini.
create or replace function public.chat_unread_counts()
returns table (thread_id uuid, unread bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select m.thread_id,
         count(msg.id) filter (
           where msg.created_at > coalesce(m.last_read_at, m.joined_at)
             and (msg.sender_profile_id is distinct from auth.uid())
         ) as unread
    from public.chat_members m
    left join public.chat_messages msg on msg.thread_id = m.thread_id
   where m.profile_id = auth.uid()
   group by m.thread_id;
$$;

revoke all on function public.chat_unread_counts() from public, anon;
grant execute on function public.chat_unread_counts() to authenticated, service_role;

-- ------------------------------------------------------
-- 6) PUSAT NOTIFIKASI
-- ------------------------------------------------------
create table if not exists public.notifikasi (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete cascade,
  siswa_id uuid references public.siswa(id) on delete cascade,
  tipe text not null default 'umum'
    check (tipe in ('tugas','pengumuman','chat','nilai','kode','umum')),
  judul text not null check (char_length(judul) between 1 and 160),
  isi text,
  ref_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint notifikasi_penerima check (profile_id is not null or siswa_id is not null)
);

create index if not exists idx_notifikasi_profile
  on public.notifikasi(profile_id, is_read, created_at desc);
create index if not exists idx_notifikasi_siswa
  on public.notifikasi(siswa_id, is_read, created_at desc);

alter table public.notifikasi enable row level security;

drop policy if exists "notifikasi: milik sendiri" on public.notifikasi;
create policy "notifikasi: milik sendiri"
on public.notifikasi for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "notifikasi: tandai dibaca" on public.notifikasi;
create policy "notifikasi: tandai dibaca"
on public.notifikasi for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

revoke all on public.notifikasi from anon, authenticated;
grant select, update on public.notifikasi to authenticated;
grant all on public.notifikasi to service_role;

-- Notifikasi otomatis untuk tugas baru dan pengumuman baru (ke akun guru).
create or replace function public.notify_guru_tugas_baru()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status_publikasi = 'published'
     and (tg_op = 'INSERT' or old.status_publikasi is distinct from 'published') then
    insert into public.notifikasi (profile_id, tipe, judul, isi, ref_id)
    select p.id, 'tugas', 'Tugas baru: ' || new.judul,
           'Tenggat ' || to_char(new.tenggat_waktu at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI'),
           new.id
      from public.profiles p
     where p.role in ('admin','guru') and p.is_active = true
       and p.id <> new.guru_id
     limit 50;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_tugas on public.tugas;
create trigger trg_notify_tugas after insert or update of status_publikasi on public.tugas
for each row execute function public.notify_guru_tugas_baru();

-- ------------------------------------------------------
-- 7) PENCARIAN GLOBAL (RLS tetap berlaku karena SECURITY INVOKER)
-- ------------------------------------------------------
create or replace function public.edutask_search(p_query text, p_limit integer default 20)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select nullif(btrim(coalesce(p_query, '')), '') as term
  ),
  lim as (
    select greatest(1, least(coalesce(p_limit, 20), 50)) as n
  ),
  hasil as (
    select 'tugas'::text as tipe, t.id::text as id, t.judul as judul,
           'Tenggat ' || to_char(t.tenggat_waktu at time zone 'Asia/Jakarta', 'DD Mon YYYY') as subjudul,
           '/guru/tugas/' || t.id::text as route,
           t.created_at as urut
      from public.tugas t, q
     where q.term is not null
       and (t.judul ilike '%' || q.term || '%' or t.deskripsi ilike '%' || q.term || '%')
    union all
    select 'kelas', k.id::text, k.nama_kelas,
           coalesce(k.tingkat, 'Kelas'), '/admin/kelas', k.created_at
      from public.kelas k, q
     where q.term is not null and k.nama_kelas ilike '%' || q.term || '%'
    union all
    select 'guru', p.id::text, p.full_name, coalesce(p.email, 'Guru'), '/admin/guru', p.created_at
      from public.profiles p, q
     where q.term is not null and p.role = 'guru' and p.full_name ilike '%' || q.term || '%'
    union all
    select 'pengumuman', a.id::text, a.judul, 'Pengumuman', '/pengumuman', a.publish_at
      from public.pengumuman a, q
     where q.term is not null
       and a.is_published = true
       and a.publish_at <= now()
       and (a.judul ilike '%' || q.term || '%' or a.isi ilike '%' || q.term || '%')
  )
  select coalesce(jsonb_agg(to_jsonb(h) order by h.urut desc), '[]'::jsonb)
    from (
      select * from hasil, lim
      order by urut desc
      limit (select n from lim)
    ) h;
$$;

revoke all on function public.edutask_search(text, integer) from public, anon;
grant execute on function public.edutask_search(text, integer) to authenticated, service_role;

-- ------------------------------------------------------
-- 8) STATISTIK AKADEMIK (dashboard admin)
-- ------------------------------------------------------
create or replace function public.akademik_stats()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'tugas_terbit', (select count(*) from public.tugas where status_publikasi = 'published'),
    'pengumpulan', (select count(*) from public.tugas_pengumpulan),
    'dinilai', (select count(*) from public.tugas_pengumpulan where status = 'dinilai'),
    'menunggu_nilai', (select count(*) from public.tugas_pengumpulan where status = 'terkirim'),
    'rata_nilai', (select coalesce(round(avg(nilai)::numeric, 1), 0) from public.tugas_pengumpulan where nilai is not null),
    'pengumuman_terbit', (select count(*) from public.pengumuman where is_published = true),
    'siswa_aktif', (select count(*) from public.siswa where status_aktif = true),
    'guru_aktif', (select count(*) from public.profiles where role = 'guru' and is_active = true)
  );
$$;

revoke all on function public.akademik_stats() from public, anon;
grant execute on function public.akademik_stats() to authenticated, service_role;

-- ------------------------------------------------------
-- 9) KESEHATAN SKEMA v006
-- ------------------------------------------------------
create or replace function public.edutask_schema_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tables jsonb;
  v_rls jsonb;
  v_policies jsonb;
  v_missing jsonb;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select jsonb_object_agg(t, to_regclass('public.' || t) is not null)
    into v_tables
    from unnest(array[
      'kode_akses_siswa','kode_akses_attempt','audit_log','siswa_akun',
      'pengumuman','kalender_akademik','tugas_pengumpulan','tugas_komentar',
      'chat_threads','chat_members','chat_messages','notifikasi'
    ]) as t;

  select jsonb_object_agg(t, coalesce((
      select c.relrowsecurity from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = t
    ), false))
    into v_rls
    from unnest(array[
      'kode_akses_siswa','audit_log','siswa','kelas','tugas',
      'pengumuman','kalender_akademik','tugas_pengumpulan','tugas_komentar',
      'chat_threads','chat_members','chat_messages','notifikasi'
    ]) as t;

  select jsonb_object_agg(t, (
      select count(*) from pg_policies p
      where p.schemaname = 'public' and p.tablename = t
    ))
    into v_policies
    from unnest(array[
      'kode_akses_siswa','audit_log','pengumuman','kalender_akademik',
      'tugas_pengumpulan','tugas_komentar','chat_threads','chat_members',
      'chat_messages','notifikasi'
    ]) as t;

  select coalesce(jsonb_agg(col order by col), '[]'::jsonb)
    into v_missing
    from unnest(array[
      'idempotency_key','kode_hash','kode_prefix','kelas_id','siswa_id',
      'single_use','status','expires_at','used_by_siswa_id','used_at',
      'revoked_at','created_by','created_at','note'
    ]) as col
   where not exists (
     select 1 from information_schema.columns ic
      where ic.table_schema = 'public'
        and ic.table_name = 'kode_akses_siswa'
        and ic.column_name = col
   );

  return jsonb_build_object(
    'checked_at', now(),
    'version', 'edutask-schema-006',
    'tables', v_tables,
    'functions', jsonb_build_object(
      'claim_kode_akses', to_regprocedure('public.claim_kode_akses(text,uuid)') is not null,
      'kode_akses_stats', to_regprocedure('public.kode_akses_stats()') is not null,
      'kode_akses_riwayat', to_regprocedure('public.kode_akses_riwayat(integer)') is not null,
      'guru_handles_kelas', to_regprocedure('public.guru_handles_kelas(uuid)') is not null,
      'edutask_search', to_regprocedure('public.edutask_search(text,integer)') is not null,
      'akademik_stats', to_regprocedure('public.akademik_stats()') is not null,
      'chat_unread_counts', to_regprocedure('public.chat_unread_counts()') is not null,
      'can_access_thread', to_regprocedure('public.can_access_thread(uuid)') is not null
    ),
    'rls_enabled', v_rls,
    'policies', v_policies,
    'missing_columns', v_missing,
    'anon_can_select_siswa', coalesce((
      select bool_or(ic.privilege_type = 'SELECT')
        from information_schema.column_privileges ic
       where ic.table_schema = 'public'
         and ic.table_name = 'siswa'
         and ic.grantee = 'anon'
    ), false)
  );
end;
$$;

revoke all on function public.edutask_schema_health() from public, anon;
grant execute on function public.edutask_schema_health() to authenticated, service_role;

-- ------------------------------------------------------
-- 10) Muat ulang schema cache PostgREST
-- ------------------------------------------------------
notify pgrst, 'reload schema';

-- ------------------------------------------------------
-- 11) Verifikasi manual (jalankan bila perlu)
-- ------------------------------------------------------
-- select public.edutask_schema_health();
-- select public.akademik_stats();
-- select * from public.chat_unread_counts();
-- select public.edutask_search('matematika');
