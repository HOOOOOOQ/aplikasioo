# EduTask — Ronde 2 ("EDUTASK ULTIMATE")

Dokumen ini mencatat **apa yang benar-benar diubah**, **bukti validasi yang benar-benar
dijalankan**, dan **apa yang belum bisa diverifikasi**. Tidak ada klaim "100% bebas bug".

Versi aplikasi dinaikkan ke **1.1.0+2** (applicationId tetap `com.edutask.sekolah`,
signing key tidak diubah).

---

## 1. Ringkasan perubahan

| Area | Status di repo | Bukti uji |
|---|---|---|
| Bucket & policy lampiran (`003`) | Selesai di repo | SQL diparse (libpg_query); **belum dijalankan di Supabase** |
| Kode akses siswa (`004` + 2 Edge Function) | Selesai di repo | SQL diparse; `tsc` strict 0 error; **belum dideploy/diuji ke server** |
| Data layer Dart (repository baru) | Selesai | `flutter analyze` 0 temuan; 85 unit/widget test lulus |
| Halaman admin (12 modul) | Selesai | Analyze + 85 test; **belum diuji runtime** |
| Halaman guru & siswa | Selesai | Analyze + 85 test; **belum diuji runtime** |
| Splash / onboarding / tentang | Selesai | Analyze + test widget onboarding/login |
| `flutter analyze` | **Lulus** | `No issues found!` (CI run `40329109136`) |
| `flutter test` | **Lulus** | 85 test, 0 gagal |
| Build APK release | **Lulus** | build #67: 4 APK, validasi paket & tanda tangan lulus |

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

**Login tidak membocorkan kredensial**: label "Email"/"Kata Sandi", placeholder umum
(`nama@email.com`), tanpa contoh email admin, tanpa kata sandi default, tanpa petunjuk
peran, tanpa akun hardcoded. Dijaga oleh `test/features/login_page_test.dart`, yang
memeriksa halaman login tidak memuat `admin@sekolah.id`, `admin123`, `Admin123`, teks
"akun demo", dan sejenisnya.

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
  progress nyata bertahap ("Memeriksa tutorial…" → "Memulihkan sesi…" → "Menyiapkan
  halaman…"); memeriksa status onboarding → memulihkan sesi (timeout 10 s) →
  menentukan role. Tidak ada delay palsu (jeda 700 ms hanya supaya animasi tidak
  berkedip, tidak menahan bila proses selesai lebih cepat). Bila gagal/timeout:
  kartu error dengan "Coba lagi" dan "Mode siswa". Dashboard tidak pernah tampil
  sebelum profil + role terverifikasi; `redirect` router juga menahan rute `/admin`
  dan `/guru` selama sesi masih dimuat.
- **Onboarding** (`features/onboarding/…`): 5 langkah sesuai brief, indikator langkah,
  tombol Lewati/Kembali/Lanjut/Mulai Sekarang, bisa dibuka lagi dari Login dan
  Pengaturan, status disimpan di `SharedPreferences` (key terpisah dari sesi sehingga
  tidak pernah menghapus sesi), tidak meminta password/kode akses. Diuji oleh
  `test/features/onboarding_test.dart` (status tersimpan, langkah berpindah, langkah
  terakhir memakai tombol "Mulai Sekarang").
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

### 8.1 Pemeriksaan statis (lokal, sebelum CI)

| Pemeriksaan | Alat | Hasil |
|---|---|---|
| Sintaks seluruh file Dart (77 file `lib`) | `tree-sitter-dart` | 0 error |
| Import relatif menunjuk file yang ada | skrip pemeriksa | 0 masalah |
| Nama argumen konstruktor widget internal | tree-sitter + pembanding parameter | 0 ketidakcocokan (104 kelas) |
| Type-check Edge Functions (TS) | `tsc` strict + shim Deno/Supabase | 0 error (4 function) |
| Sintaks SQL 001–004 | `pgsql-parser` (libpg_query) | 0 error |
| YAML workflow (3 file) | `yaml` (node) | valid |
| `config.toml` | TOML parser | valid, 4 function terdaftar |

### 8.2 Pipeline CI (bukan simulasi — dijalankan GitHub Actions)

| Pemeriksaan | Workflow / run | Hasil |
|---|---|---|
| `flutter pub get` | Verify, run `40329109136` | sukses |
| `flutter analyze` (Flutter 3.35.4) | Verify, run `40329109136` | **`No issues found!`** (0 error, 0 warning; info pun bersih) |
| `flutter test` | Verify, run `40329109136` | **85 test lulus**, 0 gagal |
| `flutter build apk --release` universal + 3 split | Build APK, run `40329109211` (build **#67**) | sukses, 4 APK |
| `unzip -t` (integritas ZIP) | build #67 | lulus |
| `aapt dump badging` | build #67 | `com.edutask.sekolah`, `sdkVersion 24`, `targetSdkVersion 36`, `versionName 1.1.0`, `versionCode 2067` |
| `apksigner verify --print-certs` | build #67 | lulus: v2 **true**, v3 **true**, 1 signer `CN=EduTask`, cert SHA-256 `f3d985e4…cbf9` |
| `zipalign -c -v 4` | build #67 | lulus |
| Uji instalasi emulator Android 14 (x86_64) | build #67, job `install-test` | **gagal boot emulator** (infrastruktur runner; langkah `continue-on-error`). Tidak ada bukti runtime dari CI. |

Catatan: `flutter analyze` dijalankan dengan `--no-fatal-infos --no-fatal-warnings`, tetapi
semua temuan tetap dicetak ke komentar PR. Run terakhir di atas **tidak menemukan satu pun
temuan**, jadi hasilnya bukan karena filter.

Cakupan 85 test tersebut:

| Berkas | Cakupan |
|---|---|
| `test/core/deadline_test.dart` | status tenggat (normal/mendekati/terlambat/selesai) |
| `test/core/attachment_validation_test.dart` | validasi ekstensi & ukuran lampiran, peta MIME, path |
| `test/core/access_code_test.dart` | status kode (aktif/terpakai/kedaluwarsa/dicabut), parsing baris DB |
| `test/core/app_error_mapping_test.dart` | pemetaan error PostgREST/Function/umum ke pesan manusiawi |
| `test/core/tugas_report_test.dart` | agregasi laporan penyelesaian |
| `test/features/onboarding_test.dart` | penyimpanan status onboarding + widget test langkah |
| `test/features/login_page_test.dart` | tidak ada kebocoran kredensial; jalur siswa tersedia |
| `test/features/auth/role_mapping_test.dart` | peran hanya dari DB; `siswa`/`student` tidak menjadi admin |
| `test/features/auth/teacher_invite_error_test.dart` | pesan error undangan guru |
| `test/widget_test.dart` | smoke test aplikasi |

Verifikasi hasil CI dapat dilihat langsung di PR #56 (komentar otomatis
"Hasil `flutter analyze`", "Hasil `flutter test`", "Validasi APK").

### 8.3 Yang tetap belum dijalankan

| Pemeriksaan | Status | Alasan |
|---|---|---|
| Instalasi & cold start di HP fisik | **belum** | tidak ada perangkat/emulator lokal di sandbox |
| Uji runtime semua alur (login, CRUD, unggah lampiran, kode akses) | **belum** | butuh Supabase aktif + perangkat |
| Menjalankan migration `003`/`004` | **belum** | tidak ada kredensial project Supabase |
| Deploy Edge Functions | **belum** | `supabase` CLI + akses project tidak tersedia |
| Uji RLS/Storage ke server sungguhan | **belum** | idem |

---

## 9. Masalah yang masih terbuka

1. **Migration & function belum diterapkan.** Tanpa menjalankan `003` dan `004` serta
   mendeploy `student-codes`/`student-access`, perbaikan Storage 403 dan kode akses baru
   belum aktif di server. Ini langkah operator, bukan kode.
2. **Belum ada uji runtime.** APK terbangun dan lolos validasi paket, tetapi belum pernah
   dijalankan di HP; emulator CI gagal boot. Semua klaim perilaku UI adalah hasil
   pembacaan kode + analyze + unit test, bukan observasi runtime.
3. **Pagination masih sisi klien** ("Muat lebih banyak" 20/25 item). Dataset besar tetap
   diambil sekaligus; server-side `range()` belum diterapkan.
4. `Tugas.copyWith` tidak bisa mengosongkan field nullable — kode yang membutuhkan
   penghapusan lampiran memakai patch eksplisit (`{'lampiran_path': null}`).
5. Beberapa repository memakai `.single()` untuk insert/update. Bila RLS menolak (0 baris),
   PostgREST mengembalikan `PGRST116` yang sudah dipetakan ke pesan "data tidak ditemukan
   atau Anda tidak berhak".
6. Fallback kode legacy `siswa.kode_akses` masih aktif agar siswa lama tidak terkunci.
   Kode ini tidak pernah dibuat aplikasi dan tidak dipakai untuk kode baru.
7. `analysis_options.yaml` masih mengabaikan `deprecated_member_use`
   (`DropdownButtonFormField.value`), agar kode tetap kompatibel dengan Flutter < 3.35.
   `unused_field`/`unused_element` sudah **tidak** diabaikan lagi.
8. Signing key rilis masih keystore test (`android/app/edutask-signing.p12`), bukan kunci
   Play Store. Sertifikat stabil antar build (bisa menimpa instalasi lama).
9. **Privasi kode kelas:** kode yang diterbitkan untuk satu kelas menampilkan daftar nama
   siswa kelas tersebut agar siswa dapat memilih namanya. Pemegang kode kelas dapat
   melihat nama-nama itu. Untuk sekolah, ini setara absensi kelas; bila tidak diinginkan,
   terbitkan kode per siswa.
10. Kode akses & laporan resmi bergantung pada Edge Function yang belum diuji ke server
    nyata (unit test hanya memverifikasi validasi klien, pemetaan error, dan format).

Catatan jujur: aplikasi ini **belum** bisa disebut "bebas bug". Yang bisa dibuktikan baru:
kode ter-compile, lolos `flutter analyze` tanpa temuan, 85 unit/widget test lulus, dan APK
release lolos validasi paket serta tanda tangan.

---

## 10. APK hasil build CI

Build **#67** dari commit `2214ea6` (branch `arena/d5efb306-aplikasioo`, PR #56):

| File | Ukuran (`du`) | SHA-256 |
|---|---|---|
| `EduTask-1.1.0-arm64-v8a.apk` | 26 MB | `b5724f859eb3d0025430cdb675c7fe88d5721cf6c835f1d923c19a344c60be73` |
| `EduTask-1.1.0-armeabi-v7a.apk` | 23 MB | `781a9202a402820e26e2c14041a5b23c65ce158c722956d7e18dafa79fc01b3c` |
| `EduTask-1.1.0-universal.apk` | 62 MB | `b549b677f7196e5a4e5f047c9d87e6738a3eac745eef1a6f849f2ecab9cfc783` |
| `EduTask-1.1.0-x86_64.apk` | 27 MB | `623c9e73c4cf9d9d7ba016cc40e7c81d55db1c2a008db5614a121e55d9d21b67` |

Informasi paket (dari `aapt`/`apksigner` di CI):

- package `com.edutask.sekolah`, versionName `1.1.0`, versionCode `2067`
- minSdk **24** (Android 7.0), targetSdk **36**, compileSdk 36
- signature v2 + v3 valid; sertifikat `CN=EduTask`, SHA-256
  `f3d985e457b01512b34091c25826869ed48fe9efd42b988375fc401562ffcbf9`
- ABI: arm64-v8a, armeabi-v7a, x86_64 (universal berisi ketiganya)

**Lokasi unduhan:**

- Artefak build PR: tab **Actions → run Build EduTask APK #67 → Artifacts →
  `edutask-apks`** (butuh login GitHub; tidak bisa diunduh dari sandbox ini).
- Rilis publik: `https://github.com/HOOOOOOQ/aplikasioo/releases/tag/latest-apk`.
  Rilis ini diperbarui **otomatis** ketika commit ini masuk ke `main`; nomor build dan
  checksum akan berbeda karena `versionCode` mengikuti nomor run, sedangkan kodenya sama.
  Checksum lengkap selalu tercantum di catatan rilis dan `SHA256SUMS.txt`.

**Cara memasang:** unduh file `.apk` langsung ke HP → buka dari notifikasi/Files → izinkan
"Install unknown apps". Bila muncul "Ada masalah saat mengurai paket", ikuti
[`apk-install-troubleshooting.md`](apk-install-troubleshooting.md).
