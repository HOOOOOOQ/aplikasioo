# EduTask — Ronde 2 ("EDUTASK ULTIMATE")

Dokumen ini mencatat **apa yang benar-benar diubah**, **bukti validasi yang benar-benar
dijalankan**, dan **apa yang belum bisa diverifikasi**. Tidak ada klaim "100% bebas bug".

Versi aplikasi dinaikkan ke **1.1.0+2** (applicationId tetap `com.edutask.sekolah`,
signing key tidak diubah).

---

## 1. Ringkasan perubahan

| Area | Status di repo | Bukti uji |
|---|---|---|
| Bucket & policy lampiran (`003`) | Selesai | SQL diparse dengan parser PostgreSQL asli |
| Kode akses siswa (`004` + 2 Edge Function) | Selesai | SQL diparse; TypeScript type-check (shim) |
| Data layer Dart (repository baru) | Selesai | Parse + pemeriksaan simbol/nama argumen |
| Halaman admin (12 modul) | Selesai | Parse; **belum dijalankan** |
| Halaman guru & siswa | Selesai | Parse; **belum dijalankan** |
| Splash / onboarding / tentang | Selesai | Parse; **belum dijalankan** |
| `flutter analyze` / `flutter test` / APK | **Tidak dijalankan** | Toolchain tidak tersedia di sandbox |

---

## 2. Storage 403 — akar masalah dan perbaikan

### Akar masalah (terbukti dari repo)
1. `supabase/migrations/001_initial_schema.sql` hanya memuat **komentar** untuk
   `insert into storage.buckets (...)` dan `create policy ... on storage.objects`.
   Tidak ada migration yang membuat bucket `lampiran-tugas`, sehingga Storage
   menolak INSERT dengan `new row violates row-level security policy` → **403**.
2. Path lampiran lama `"${millis}_$fileName"` berada di root bucket tanpa identitas
   pemilik → policy berbasis kepemilikan tidak mungkin ditulis.
3. Unggahan terjadi **sebelum** baris `tugas` dibuat → bila unggah gagal, tidak ada
   rollback; bila insert tugas gagal, file menjadi yatim.
4. Tidak ada validasi MIME/ukuran di sisi bucket, tidak ada policy DELETE.

### Perbaikan
- `supabase/migrations/003_storage_attachments.sql`
  - Membuat bucket **privat** `lampiran-tugas` (10 MB, allowlist MIME).
  - Policy SELECT/INSERT/UPDATE/DELETE untuk `storage.objects`:
    admin, guru pemilik path `tugas/<guru_id>/<tugas_id>/<file>`, dan pembacaan
    (anon + authenticated) **hanya** bila file dirujuk tugas berstatus `published`.
  - Tidak ada bucket public, tidak ada penonaktifan RLS.
- `lib/shared/services/attachment_service.dart` — satu pintu unggah/hapus/signed URL,
  validasi ekstensi + ukuran.
- `lib/features/teacher/presentation/pages/teacher_task_form_page.dart` — urutan aman:
  1. insert `tugas` (draft, `lampiran_path = null`)
  2. unggah file ke path ber-pemilik
  3. `update` `lampiran_path` + status publikasi
  4. bila langkah 2/3 gagal → file baru dihapus, tugas yang baru dibuat dihapus
     (tidak ada tugas "setengah jadi" yang tampil ke siswa)
  5. saat edit: unggah dulu → update DB → hapus file lama; bila update gagal,
     file baru dihapus.
- `lib/features/admin/presentation/pages/admin_task_detail_page.dart` — hapus tugas
  oleh admin ikut menghapus objek lampiran (tidak meninggalkan file yatim).

**Catatan:** migration `003` **belum dijalankan** di project Supabase mana pun dari
sesi ini. Tanpa menjalankannya, 403 akan tetap terjadi.

---

## 3. Kode akses siswa (server-side)

### Skema (`supabase/migrations/004_access_codes_audit.sql`)
- `kode_akses_siswa`: `kode_hash` (SHA-256, unik), `kode_prefix` (tampilan),
  `kelas_id`, `siswa_id` (opsional), `single_use`, `status`
  (`active|used|revoked|expired`), `expires_at`, `used_at`, `used_by_siswa_id`,
  `created_by`, `note`. **Tidak ada plaintext kode.**
- RLS: admin baca semua; guru hanya kelas yang ditanganinya (`guru_handles_kelas`).
  **Tidak ada policy INSERT/UPDATE/DELETE** → hanya service_role (Edge Function).
- `kode_akses_attempt` untuk rate limit (tidak bisa dibaca client).
- `audit_log` + trigger `audit_row_change()` pada profiles/kelas/siswa/mapel/jadwal/
  tugas/kode_akses_siswa.
- `claim_kode_akses(p_kode_hash, p_siswa_id)` — `security definer`, `SELECT … FOR UPDATE`,
  memvalidasi status/expiry/kelas/single-use lalu menandai terpakai dalam satu transaksi.
  Hanya `service_role` yang boleh `execute`.

### Edge Functions
- `student-codes` (baru): `issue` / `revoke`.
  - JWT diverifikasi ulang ke `profiles` (role + `is_active`), bukan mempercayai klaim client.
  - Guru dibatasi ke kelas yang diampu (`wali_kelas_id`, jadwal, atau `guru_mapel`).
  - Kode: CSPRNG `EDT-XXXXX-XXXXX` (alphabet tanpa karakter ambigu) dengan
    **rejection sampling** (tanpa bias modulo), hanya hash yang disimpan.
  - Masa berlaku 1–365 hari, single-use default `true`, audit `issue`/`revoke`.
- `student-access` (ditulis ulang):
  - Rate limit 10 percobaan / 10 menit per IP.
  - Mode per-siswa: klaim atomik lewat RPC lalu terbit token.
  - Mode per-kelas: mengembalikan `claim_token` (HMAC, 15 menit); langkah 2 memvalidasi
    siswa benar-benar berada di kelas tersebut sebelum klaim.
  - Error bertipe: `not_found`, `used`, `revoked`, `expired`, `class_mismatch`,
    `too_many_attempts` → pesan berbeda di UI.
  - Fallback kode legacy (`siswa.kode_akses`) dipertahankan agar siswa lama tidak
    terkunci; jalur ini tetap diverifikasi di server dan **tidak dipakai untuk kode baru**
    (form siswa tidak lagi bisa menulis `kode_akses`).

### Klien
- `lib/features/student/identity/student_identity_provider.dart` & `student_identity_page.dart`
  — verifikasi kode, pemilihan nama untuk kode kelas, kartu status terverifikasi,
  penjelasan resmi vs lokal.
- `lib/features/access_codes/…` — halaman "Manajemen Kode Akses Siswa" (filter status,
  pencarian, terbitkan per siswa/kelas, expiry, single-use, catatan, dialog kode
  sekali-tampil + salin, cabut kode).
- Status tugas siswa: **resmi** hanya lewat Edge Function `update-student-task-status`
  (HMAC). Tanpa verifikasi, status hanya tersimpan lokal (`localTaskStatusProvider`)
  dan UI menandainya jelas (`StatusSourceBadge`).

---

## 4. Halaman admin (12 modul, semua terhubung backend)

| Modul | File | CRUD/aksi |
|---|---|---|
| Dashboard | `admin_dashboard_page.dart` | statistik, tugas terbaru, audit terbaru |
| Data guru | `admin_teachers_page.dart` | undang guru (Edge Function), aktif/nonaktif |
| Data siswa | `admin_students_page.dart` | tambah/edit/hapus, filter kelas, pencarian, muat lebih banyak |
| Kelas | `admin_classes_page.dart` | CRUD, wali kelas, jumlah siswa |
| Mata pelajaran | `admin_subjects_page.dart` | CRUD |
| Jadwal | `admin_schedules_page.dart` | CRUD, filter kelas/hari, validasi jam, konflik ditolak trigger DB |
| Tugas | `admin_tasks_page.dart` | filter status/kelas, terbitkan/draft, hapus, buka detail |
| Detail tugas | `admin_task_detail_page.dart` | lihat lampiran (signed URL), edit, terbitkan/draft, hapus + lampiran |
| Laporan | `admin_reports_page.dart` | **agregat nyata** dari `status_tugas_siswa` (bukan pie hardcoded) |
| Kode akses | `access_codes_page.dart` | terbitkan/cabut, riwayat |
| Akun & role | `admin_accounts_page.dart` | ubah role, aktif/nonaktif, proteksi akun sendiri |
| Audit log | `admin_audit_page.dart` | 200 entri terakhir, filter entitas/aksi, muat lebih banyak |
| Pengaturan | `admin_settings_page.dart` | info server (tanpa URL rahasia), data lokal, tutorial, logout |
| Tentang | `about_page.dart` | tim, sekolah, jurusan, tautan Instagram |

Semua halaman: loading (skeleton), empty state, error state + coba lagi,
tarik-untuk-refresh, dialog konfirmasi untuk aksi merusak.

**Login tidak membocorkan kredensial**: label "Email"/"Kata Sandi", placeholder umum,
tanpa contoh email admin, tanpa peran default, tanpa akun hardcoded.

---

## 5. Desain ulang UI

Design system bersama:
- `core/constants/app_colors.dart` — biru primer `#1A56DB`, permukaan netral, warna status,
  gradien, `AppSpacing` (4/8/12/16/20/24/32), radius, durasi animasi.
- `core/theme/app_theme.dart` — Material 3, tipografi, input, kartu, snackbar, navigasi.
- Widget: `AppHeroHeader`, `SectionHeader`, `MetricTile`, `InfoRow`, `InitialsAvatar`,
  `AppCard`, `AppSearchField`, `AppNotice`, `AppEmptyState`, `AppErrorState`,
  `AppSkeletonList`, `AppLoading`, `StatusChip`, `StatusSourceBadge`, `MetaPill`,
  `EduTaskLogo`, `showConfirmDialog`, `showAppSnackBar`.

Halaman yang didesain ulang/dibuat: splash, onboarding, login, tentang, identitas siswa,
beranda siswa, jadwal siswa, daftar tugas siswa, detail tugas siswa, shell admin,
dashboard admin, 11 halaman admin di atas, shell guru, dashboard guru, jadwal guru,
tugas guru, form tugas guru, status siswa (guru), profil guru.

Responsif: `ListView` + `Wrap`/`GridView`, `SafeArea`, `viewInsets` pada bottom sheet,
`MediaQuery.textScaler` dibatasi 0.9–1.3, kontras teks mengikuti palet.

---

## 6. Splash, onboarding, tentang

- **Splash** (`core/widgets/splash_page.dart`): logo + nama + tagline, animasi halus,
  progress nyata; memeriksa status onboarding → memulihkan sesi (timeout 10 s) →
  menentukan role. Tidak ada delay palsu (minimum tampil 650 ms). Bila gagal:
  kartu error dengan "Coba lagi" dan "Lanjut tanpa login". Dashboard tidak pernah
  tampil sebelum profil + role terverifikasi.
- **Onboarding** (`features/onboarding/…`): 5 langkah sesuai brief, indikator langkah,
  tombol Lewati/Kembali/Lanjut/Mulai Sekarang, bisa dibuka lagi dari Pengaturan,
  status disimpan di `SharedPreferences`, tidak pernah menghapus sesi, tidak meminta
  password/kode akses.
- **Tentang** (`features/about/…`): tujuan, fitur, tim (Noval Rizki — Developer,
  Rohiman — Partner, Fikri Muhammad Faiz — Penyedia), SMK Al Madani Garut, PPLG,
  motto "From 3 Person To All", "© 2026 PALL. All rights reserved.", tautan Instagram
  yang bisa diketuk. Secara eksplisit menyatakan **bukan aplikasi resmi sekolah**.

---

## 7. Migration & policy

| File | Isi | Dijalankan? |
|---|---|---|
| `003_storage_attachments.sql` | bucket privat + 5 policy Storage, audit objek path lama | **Belum** |
| `004_access_codes_audit.sql` | helper `guru_handles_kelas`, `kode_akses_siswa`, `siswa_akun`, `kode_akses_attempt`, `audit_log`, trigger audit, RPC `claim_kode_akses` | **Belum** |

Urutan deploy yang benar:
1. Deploy Edge Functions (`student-codes`, `student-access`, `update-student-task-status`).
2. Jalankan `003` lalu `004` di SQL Editor.
3. Baru unggah lampiran/dashboard kode akses dipakai.

Keduanya idempotent dan sudah diverifikasi **sintaksnya** dengan parser PostgreSQL
(`libpg_query` via `pgsql-parser`).

---

## 8. Hasil validasi yang benar-benar dijalankan

| Pemeriksaan | Alat | Hasil |
|---|---|---|
| Sintaks seluruh file Dart (82 file) | `tree-sitter-dart` | 0 error |
| Import relatif menunjuk file yang ada | skrip pemeriksa | 0 masalah |
| Import tak terpakai | skrip pemeriksa | 0 (setelah pembersihan) |
| Nama argumen konstruktor widget internal | tree-sitter + pembanding parameter | 0 ketidakcocokan (104 kelas) |
| Referensi provider/`Repository().method` | skrip pemeriksa | 0 hilang |
| Type-check Edge Functions (TS) | `tsc` strict + shim Deno/Supabase | 0 error |
| Sintaks SQL 001–004 | `pgsql-parser` (libpg_query) | 0 error |
| YAML workflow | `yaml` (node) | valid |
| `config.toml` | TOML parser | valid, 4 function terdaftar |
| `flutter analyze` | — | **tidak dijalankan** (tidak ada Flutter di sandbox) |
| `flutter test` | — | **tidak dijalankan** (test baru ditulis, belum dieksekusi) |
| Build APK | — | **tidak dijalankan** (tidak ada JDK/Android SDK) |
| Runtime di perangkat/emulator | — | **tidak dijalankan** |

Test unit baru (belum dieksekusi): `test/core/attachment_validation_test.dart`,
`test/core/access_code_test.dart`, `test/core/app_error_mapping_test.dart`,
`test/core/tugas_report_test.dart`.

---

## 9. Masalah yang masih terbuka

1. **Tidak ada build/verifikasi runtime** pada sesi ini; APK ronde 2 belum ada.
2. Migration `003`/`004` belum dijalankan di project Supabase mana pun.
3. Edge Function `student-codes`/`student-access` belum dideploy; `student-codes` belum
   diuji ke server sungguhan.
4. Pagination masih sisi klien ("muat lebih banyak" 20/25 item); belum server-side
   `range()`.
5. `Tugas.copyWith` tidak bisa mengosongkan field nullable (gunakan patch eksplisit).
6. Beberapa repository masih memakai `.single()` untuk insert/update — tetap error bila
   0/2 baris (perilaku PostgREST), ditangani sebagai error yang bisa dibaca pengguna.
7. Fallback kode legacy `siswa.kode_akses` masih aktif untuk kompatibilitas.
8. `analysis_options.yaml` masih mengabaikan beberapa lint (`unused_field`,
   `unused_element`, `deprecated_member_use`).
9. Signing key rilis masih test keystore (`android/app/edutask-signing.p12`), bukan
   kunci Play Store.
