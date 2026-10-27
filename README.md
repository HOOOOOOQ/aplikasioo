# EduTask

**Tugas & Jadwal Sekolah** — aplikasi Flutter + Supabase untuk mengelola jadwal pelajaran,
tugas, lampiran, kode akses siswa, dan laporan penyelesaian tugas.

> **Ronde 6 (v1.2.0):** **ekspor PDF laporan** (satu sumber data dengan CSV —
> filter kelas/guru/mapel/periode, template A4 landscape dengan identitas
> EduTask, ringkasan statistik, header berulang, dan “Halaman X dari Y”;
> Android memakai dialog cetak/bagikan sistem, Web mengunduh berkas PDF asli
> tanpa CDN) dan **pin tugas** (migration `007`: `is_pinned`, `position`, RPC
> `set_tugas_pin` — RLS + pemeriksaan ulang otorisasi server, urutan
> pin → position → tenggat → id). Hasil CI: `flutter analyze` 0 error,
> **210 tes lulus**, `build web` + `build apk` hijau (build #96).
> **Migration `007` belum dijalankan** di database mana pun.
> SQL lengkap, langkah manual, hasil CI, dan batasan yang belum diuji:
> [`docs/round6-edutask.md`](docs/round6-edutask.md).
>
> **Ronde 5 (v1.2.0, build #87):** **target Flutter Web** (scaffold `web/`,
> conditional import untuk notifikasi/CSV/URL strategy), **onboarding 8 langkah**,
> halaman **Bantuan & FAQ**, **Guru Kelas**, **Kalender Tenggat**, **Riwayat Kode
> Akses**, **Sesi Perangkat**, **Ekspor CSV laporan**, pengingat tenggat yang
> benar-benar dijadwalkan, ukuran teks aksesibel (90–140 %), serta perbaikan
> bug alur tutorial & konteks audio iOS.
> Detail: [`docs/round5-edutask.md`](docs/round5-edutask.md).
>
> **Ronde 4 (v1.2.0, build #80):** navigasi Back yang konsisten (konfirmasi
> keluar di beranda), kode akses idempoten + tampil tanpa navigasi otomatis,
> fondasi akademik & chat (pengumuman, kalender, pengumpulan/nilai, diskusi,
> chat realtime, notifikasi, pencarian), splash baru dengan suara pembuka
> opsional, serta tutorial 5 langkah.
> Detail: [`docs/round4-edutask.md`](docs/round4-edutask.md).
>
> **Ronde 3 (v1.2.0):** perbaikan skema database kode akses (migration `005`),
> verifikasi sesi/token yang benar pada Edge Function, refresh sesi otomatis
> sekali saat server menolak token, serta pesan error spesifik.
> Detail: [`docs/round3-edutask.md`](docs/round3-edutask.md).

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
- Splash dengan pemeriksaan nyata (onboarding → sesi → role), onboarding 8 langkah yang
  dapat dibuka ulang (dari Pengaturan maupun halaman login), halaman Tentang berisi
  tim & sekolah, serta halaman Bantuan & FAQ per peran.
- Berjalan di **Android** dan **Web** dari satu basis kode; ekspor CSV laporan
  (berkas di Android, papan klip di Web).
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

## Menjalankan di Web (Flutter Web)

Target Web memakai kode yang sama dengan Android. Perbedaan platform ditangani
lewat *conditional import* (`lib/core/routing/url_strategy*.dart`,
`lib/features/notifications/notification_backend_*.dart`,
`lib/core/services/csv_saver*.dart`), sehingga tidak ada plugin Android yang
dipanggil di browser.

```bash
# 1) Jalankan mode pengembangan di http://localhost:8080
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

# 2) Build rilis (folder build/web)
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Catatan:

- **URL**: default memakai *hash strategy* (`http://localhost:8080/#/admin`) agar
  refresh/Back bekerja di semua static server tanpa rewrite. Untuk URL bersih
  (`/admin`) build ulang dengan `--dart-define=USE_PATH_URL_STRATEGY=true` dan
  pastikan host mengarahkan semua rute ke `index.html` (lihat `web/_redirects`).
- **Notifikasi lokal**: hanya tersedia di Android. Di Web tombolnya dinonaktifkan
  dengan penjelasan, sedangkan pusat notifikasi in-app tetap berfungsi.
- **Suara pembuka**: browser dapat memblokir audio otomatis (*autoplay policy*).
  Jika diblokir, aplikasi tetap berjalan tanpa suara - tidak ada error ke pengguna.
- **Ekspor CSV**: di Web memakai "Salin CSV" ke papan klip; di Android berkas
  ditulis ke direktori sementara aplikasi.
- **Produksi**: sajikan `build/web` lewat HTTPS. Untuk hosting statis (Netlify /
  Cloudflare Pages) salin `web/_redirects`; untuk Nginx gunakan
  `try_files $uri $uri/ /index.html;` bila memakai path strategy.

## Backend

### Migrasi (jalankan berurutan di SQL Editor / `supabase db push`)

| File | Isi |
|---|---|
| `supabase/migrations/001_initial_schema.sql` | Tabel inti: profiles, kelas, siswa, mata_pelajaran, guru_mapel, jadwal_pelajaran, tugas, status_tugas_siswa |
| `supabase/migrations/002_security_hardening.sql` | Grant kolom terbatas, policy RLS diperketat, helper `is_admin()`/`is_guru()` |
| `supabase/migrations/003_storage_attachments.sql` | Bucket **privat** `lampiran-tugas`, policy Storage lengkap, path `tugas/<guru_id>/<tugas_id>/<file>` |
| `supabase/migrations/004_access_codes_audit.sql` | `kode_akses_siswa`, `siswa_akun`, `kode_akses_attempt`, `audit_log` + trigger, RPC `claim_kode_akses` |
| `supabase/migrations/005_access_codes_schema_repair.sql` | **Perbaikan idempoten**: tabel/kolom/FK/index/policy kode akses yang belum ada, RPC `kode_akses_stats()` (statistik dashboard), `edutask_schema_health()` (diagnostik admin), `notify pgrst 'reload schema'` |
| `supabase/migrations/006_round4_academic_chat.sql` | Idempotency kode akses (`idempotency_key`), pengumuman, kalender, pengumpulan tugas + revisi + nilai, diskusi, chat privat/grup/diskusi, pusat notifikasi, RPC pencarian & statistik, riwayat kode akses |

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
| `student-portal` | tidak | Portal siswa bertoken: pengumuman, kalender, tugas, pengumpulan, notifikasi |
| `student-chat` | tidak | Chat siswa bertoken: thread, pesan, guru kelas (`guru_list`), unread |

```bash
supabase functions deploy create-teacher
supabase functions deploy student-access
supabase functions deploy student-codes
supabase functions deploy update-student-task-status
supabase functions deploy student-portal
supabase functions deploy student-chat
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
web/           index.html, manifest PWA, ikon, fallback SPA
test/          unit test murni (tanpa jaringan)
docs/          laporan ronde 2-5 & panduan instalasi APK
```

## Tim

Dikembangkan oleh **Noval Rizki** (Developer), **Rohiman** (Partner), dan
**Fikri Muhammad Faiz** (Penyedia) — *From 3 Person To All*.
SMK Al Madani Garut · PPLG — Pengembangan Perangkat Lunak dan Gim.

© 2026 PALL. All rights reserved.
