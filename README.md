# EduTask

**Tugas & Jadwal Sekolah** — aplikasi Flutter + Supabase untuk mengelola jadwal pelajaran,
tugas, lampiran, kode akses siswa, dan laporan penyelesaian tugas.

> **Ronde 3 (v1.2.0):** perbaikan skema database kode akses (migration `005`),
> verifikasi sesi/token yang benar pada Edge Function, refresh sesi otomatis sekali
> saat server menolak token, serta pesan error spesifik (skema, sesi, kode akses).
> Detail: [`docs/round3-edutask.md`](docs/round3-edutask.md).
>
> **Ronde 2 (v1.1.0):** perbaikan akar masalah Storage 403, sistem kode akses siswa
> berbasis server, modul admin yang terhubung backend, serta desain ulang UI.
> Detail perubahan, bukti validasi, dan daftar hal yang belum diuji:
> [`docs/round2-edutask.md`](docs/round2-edutask.md).
>
> Aplikasi ini **bukan** aplikasi resmi sekolah. Status "resmi" pada tugas hanya
> berarti laporan siswa sudah diverifikasi server melalui kode akses.

---

## Fitur utama

| Peran | Kemampuan |
|---|---|
| **Admin** | Dashboard statistik, data guru (undang via Edge Function), data siswa (aktif/nonaktif), kelas, mata pelajaran, jadwal (anti-bentrok), tugas + lampiran, laporan penyelesaian, manajemen kode akses siswa, akun & role, audit log, pengaturan, tentang |
| **Guru** | Jadwal mengajar, CRUD tugas + lampiran (milik sendiri), terbitkan/draft, arsipkan, status penyelesaian siswa, penerbitan kode akses untuk kelas yang diampu, profil |
| **Siswa (tanpa login)** | Jadwal dan tugas per kelas, detail tugas + lampiran, verifikasi kode akses di halaman Identitas, status selesai tersimpan **lokal** atau **resmi (server)** |

- Material 3, tema biru, komponen bersama (`AppCard`, `AppHeroHeader`, `AppEmptyState`,
  `AppErrorState`, `StatusChip`, dan lainnya).
- Splash dengan pemeriksaan nyata (onboarding → sesi → role), onboarding 5 langkah yang
  dapat dibuka ulang, halaman Tentang berisi tim & sekolah.
- Login hanya memakai label "Email" dan "Kata Sandi" — tidak ada petunjuk kredensial,
  akun contoh, atau akun admin hardcoded.

## Stack

- Flutter (Dart 3) · Riverpod · GoRouter
- Supabase: Postgres + RLS, Auth, Storage, Edge Functions (Deno/TypeScript)
- Android `minSdk 24`, `targetSdk 36`, `applicationId com.edutask.sekolah`
- CI GitHub Actions: analyze + test, build APK release (universal & split-per-ABI),
  validasi `aapt`/`apksigner`/`zipalign`, publikasi ke Release `latest-apk`

## Menjalankan secara lokal

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Tanpa dua nilai di atas aplikasi berjalan dalam **mode terbatas** (banner peringatan,
data kosong). Jangan pernah menaruh `service_role` di aplikasi Flutter.

Analisis & uji:

```bash
flutter analyze
flutter test
```

## Backend

### Migrasi (jalankan berurutan di SQL Editor / `supabase db push`)

| File | Isi |
|---|---|
| `supabase/migrations/001_initial_schema.sql` | Tabel inti: profiles, kelas, siswa, mata_pelajaran, guru_mapel, jadwal_pelajaran, tugas, status_tugas_siswa |
| `supabase/migrations/002_security_hardening.sql` | Grant kolom terbatas, policy RLS diperketat, helper `is_admin()`/`is_guru()` |
| `supabase/migrations/003_storage_attachments.sql` | Bucket **privat** `lampiran-tugas`, policy Storage lengkap, path `tugas/<guru_id>/<tugas_id>/<file>` |
| `supabase/migrations/004_access_codes_audit.sql` | `kode_akses_siswa`, `siswa_akun`, `kode_akses_attempt`, `audit_log` + trigger, RPC `claim_kode_akses` |
| `supabase/migrations/005_access_codes_schema_repair.sql` | **Perbaikan idempoten**: tabel/kolom/FK/index/policy kode akses yang belum ada, RPC `kode_akses_stats()` (statistik dashboard), `edutask_schema_health()` (diagnostik admin), `notify pgrst 'reload schema'` |

> **Penting (round 3):** `005` aman dijalankan berulang kali dan tidak menghapus data.
> Jalankan bila aplikasi menampilkan *"Could not find the table 'public.kode_akses_siswa'
> in the schema cache"*. Setelah migration, tabel/fungsi langsung dikenali PostgREST
> karena file diakhiri `notify pgrst, 'reload schema'`.

### Edge Functions

| Function | JWT | Kegunaan |
|---|---|---|
| `create-teacher` | ya | Undang akun guru (hanya admin) |
| `student-access` | tidak | Verifikasi kode akses siswa, rate limit, klaim atomik |
| `student-codes` | ya | Terbitkan/cabut kode akses (admin/guru) |
| `update-student-task-status` | tidak | Tandai tugas selesai dengan token siswa (HMAC); kode error `student_token_*` |

```bash
supabase functions deploy create-teacher
supabase functions deploy student-access
supabase functions deploy student-codes
supabase functions deploy update-student-task-status
```

Urutan aman: **deploy function → jalankan 003 → jalankan 004 → jalankan 005**.

`005` mengulang (idempoten) seluruh DDL dari `004` sehingga juga memperbaiki project
yang `004`-nya belum pernah dijalankan. Deploy function dulu agar aplikasi versi baru
tidak memanggil fungsi lama yang memverifikasi token dengan cara yang salah.

## Build APK

Workflow `Build EduTask APK` menghasilkan APK universal + split-per-ABI, menandatangani
ulang secara deterministik, lalu memvalidasi paket. Rilis terbaru:
`https://github.com/HOOOOOOQ/aplikasioo/releases/tag/latest-apk`.

Jika APK gagal dipasang di perangkat, ikuti
[`docs/apk-install-troubleshooting.md`](docs/apk-install-troubleshooting.md).

## Struktur proyek

```
lib/
  core/        konfigurasi, tema, routing, widget bersama, util
  features/    auth, admin, teacher, student, access_codes, onboarding, about
  shared/      model, repository, service Supabase
supabase/
  migrations/  skema + policy + trigger
  functions/   Edge Functions (Deno)
test/          unit test murni (tanpa jaringan)
docs/          laporan ronde 2 & panduan instalasi APK
```

## Tim

Dikembangkan oleh **Noval Rizki** (Developer), **Rohiman** (Partner), dan
**Fikri Muhammad Faiz** (Penyedia) — *From 3 Person To All*.
SMK Al Madani Garut · PPLG — Pengembangan Perangkat Lunak dan Gim.

© 2026 PALL. All rights reserved.
