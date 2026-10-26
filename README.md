# EduTask — Aplikasi Tugas dan Jadwal Pelajaran Sekolah

<p align="center">
  <img src="assets/images/edutask_banner.png" alt="EduTask Banner" width="100%" />
</p>

<p align="center">
  <img src="assets/images/edutask_logo.png" alt="EduTask Logo" width="140" />
  <br/>
  <strong>Package:</strong> <code>com.edutask.sekolah</code> |
  <strong>Framework:</strong> Flutter 3.35.4 Stable |
  <strong>Backend:</strong> Supabase (PostgreSQL) |
  <strong>Design:</strong> Material 3
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.35.4-02569B?style=for-the-badge&logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-%3E%3D3.4.0-0175C2?style=for-the-badge&logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Supabase-Postgres-3FCF8E?style=for-the-badge&logo=supabase" alt="Supabase"/>
  <img src="https://img.shields.io/badge/Platform-Android-34C759?style=for-the-badge&logo=android" alt="Android"/>
</p>

Aplikasi Android modern untuk mengelola tugas, jadwal pelajaran, dan laporan penyelesaian tugas dengan 3 peran **Admin**, **Guru**, dan **Siswa (tanpa login)**. Dibangun feature-first, Riverpod + GoRouter, anti-force-close, siap install di semua Android 5.1+.

---

## 🖼️ Tampilan Aplikasi

| Siswa — Beranda & Kelas | Siswa — Jadwal | Siswa — Daftar Tugas |
|---|---|---|
| Banner EduTask + pilih kelas → jadwal & tugas langsung muncul | Filter hari: Semua / Hari Ini / Besok / Senin–Minggu | Search, filter status (Selesai/Mendekati/Terlambat), filter mapel |

| Admin Dashboard | Guru Dashboard | Detail Tugas |
|---|---|---|
| Statistik siswa/guru/kelas/mapel + drawer manajemen | Jadwal hari ini & tugas aktif + status siswa | Lampiran, tenggat Asia/Jakarta, warna deadline, tombol selesai via kode |

> Banner & logo di atas (`assets/images/edutask_banner.png` dan `edutask_logo.png`) dipakai langsung di aplikasi: Splash (logo 110 + banner), Login, Student Home AppBar + banner, Admin/Teacher Drawer Header, About page. Launcher icon Android `mipmap-*` juga dari logo yang sama.

Untuk screenshot fisik: jalankan `flutter run` lalu ambil screenshot dari emulator/device dan letakkan di folder `docs/screenshots/` — otomatis tampil di README ini setelah di-push.

---

## ✨ Fitur Lengkap & Status

### 👨‍🎓 Siswa — Tanpa Login (publik)
- ✅ Langsung masuk Beranda — tidak perlu login
- ✅ Pilih kelas → lihat jadwal & tugas kelas tersebut dari Supabase
- ✅ Jadwal: filter Semua / Hari Ini / Besok / Senin–Minggu, group by hari, highlight hari ini/besok
- ✅ Daftar Tugas: search judul/mapel, filter status (Semua/Belum selesai/Selesai/Mendekati tenggat/Terlambat), filter mapel
- ✅ Detail tugas: guru, kelas, deskripsi, lampiran (Storage public URL), download via `url_launcher`
- ✅ Deadline helper: **hijau** selesai, **oranye** <24 jam, **merah** terlambat, **biru** aktif — zona **Asia/Jakarta** (`timezone` + `AppDateUtils.toJakarta`)
- ✅ Tandai selesai:
  - **Utama (server-validated):** Masukkan **Kode Siswa** (`SISWA-XXX` unik dari sekolah) → validasi via Edge Function `update-student-task-status` + `student-access` (token terbatas) → baris `status_tugas_siswa` tampil di laporan guru/admin
  - **Fallback lokal (offline/demo):** Tanpa kode → status `selesai` disimpan di perangkat (`SharedPreferences` via `localTaskStatusProvider`) — eksplisit dijelaskan di UI sebagai *tidak resmi*
- ✅ **Anti-FC:** Semua halaman siswa guard `SupabaseConfig.isNotConfigured` / `SupabaseService.isReady`. Saat demo tanpa config, tampil `EmptyState`/pesan mode demo — tidak throw `StateError` atau stuck di `LinearProgressIndicator`.

### 👨‍🏫 Guru — Login via Supabase Auth
- ✅ Login `email + password` (`supabase_auth`) → tabel `profiles.role = guru`
- ✅ Dashboard: jadwal mengajar hari ini (via `JadwalRepository.fetchByGuru`), tugas aktif, mendekati tenggat, ringkasan penyelesaian
- ✅ CRUD tugas miliknya: judul/deskripsi/kelas/mapel/tanggal mulai & tenggat — jam selesai > jam mulai divalidasi
- ✅ Lampiran upload: `file_picker` → `TugasRepository.uploadLampiran` ke bucket `lampiran-tugas` (max 10MB, ekstensi `pdf/doc/ppt/jpg/png/zip` dll) + `getPublicUrl()`
- ✅ Halaman Status Siswa per tugas: `fetchStatusForTugas` + `fetchSummary` (total siswa di kelas vs selesai/belum)
- ✅ Guard: semua fetch via `tryClient` + early `isNotConfigured` return; delete dengan `confirm_dialog`; error SnackBar bukan FC

### 👨‍💼 Admin — Login via Supabase Auth
- ✅ Dashboard statistik: total siswa/guru/kelas/mapel/jadwal/tugas aktif (kartu metrik)
- ✅ CRUD Siswa: NIS unik, pilih kelas via `DropdownButtonFormField` (guarded), kode akses auto `SISWA-<NIS>-<epoch>`
- ✅ CRUD Guru: undang via Edge Function `create-teacher` (service_role hanya di server), fallback info jika belum deploy
- ✅ CRUD Kelas: `nama_kelas` + `tingkat` + `tahun_ajaran` + `wali_kelas`
- ✅ CRUD Mapel: `nama_mapel` + deskripsi
- ✅ Jadwal Pelajaran: `kelas_id + hari + jam_mulai/jam_selesai + guru_id` — trigger DB anti-bentrok kelas/guru, validasi `jam_selesai > jam_mulai`
- ✅ Manajemen Tugas (read + hapus) & Laporan: filter kelas, ringkasan PieChart (`fl_chart`), persentase `selesai/total` per tugas via `TugasRepository.fetchSummary`
- ✅ Pengaturan & Status Supabase — indikator configured/not configured

---

## 🛠️ Teknologi & Versi Terkunci

- **Flutter** 3.35.4 Stable, **Dart** ≥3.4.0 (tested `sdk: ">=3.4.0 <4.0.0"`)
- **State:** `flutter_riverpod 2.5.1`
- **Routing:** `go_router 14.2.7` (redirect: splash → `/siswa` / `/login` / `/admin` / `/guru` sesuai role & `SupabaseConfig.isNotConfigured`)
- **Backend:** `supabase_flutter 2.5.6` — PostgreSQL + Auth + Storage + Edge Functions + Realtime (opsional)
- **Lainnya:** `intl 0.20.2`, `shared_preferences 2.3.2`, `flutter_local_notifications 17.1.2`, `timezone 0.9.2`, `file_picker 8.0.6`, `fl_chart 0.69.0`, `cached_network_image 3.3.0`, `url_launcher 6.2.5`, `logger 2.4.0`, `gap 3.0.1`, `shimmer 3.0.0`
- **Android:** `compileSdk 36`, `minSdk 21` (Android 5.1+), `targetSdk 36`, `AGP 8.11.1`, `Gradle 8.13`, `Kotlin 2.1.0`, `Java 17`, `NDK flutter.ndkVersion`, `multiDexEnabled true`, `coreLibraryDesugaring 2.1.4`
- **Launcher icon:** 5 density mipmap (`mdpi 48` → `xxxhdpi 192`) dari `edutask_logo.png` via ImageMagick — tidak lagi 68-byte placeholder
- **Assets:** `assets/images/edutask_logo.png` (776KB) + `edutask_banner.png` (795KB) → dipakai `app_banner.dart` (`EduTaskLogo`/`EduTaskBanner`/`EduTaskHeaderBanner`) dengan `errorBuilder` fallback gradient

---

## 📦 Persyaratan Instalasi (Laptop)

- Flutter SDK stable **≥3.22.0** (disarankan **3.35.4** sama seperti CI) — https://docs.flutter.dev/get-started/install
- Dart ≥3.4.0 (bundle Flutter)
- Android Studio / VS Code + Android SDK
- Java **17** (Temurin) — wajib untuk AGP 8.11.1 + Gradle 8.13
- Akun Supabase gratis — https://supabase.com
- Git

Cek:
```bash
flutter doctor -v
flutter --version
java -version   # harus 17
```

---

## ⚙️ Cara Atur Supabase (5 langkah)

### 1. Buat Project Supabase
Dashboard → **New Project** → nama `EduTask` → catat **Project URL** (`https://xxx.supabase.co`) & **anon key** (Project Settings → API → `anon public`).

### 2. Jalankan SQL Migration
Supabase → **SQL Editor** → **New query** → copy-paste `supabase/migrations/001_initial_schema.sql` → **Run**.  
Isinya: 8+ tabel (`profiles`, `siswa`, `kelas`, `mata_pelajaran`, `guru_mapel`, `jadwal_pelajaran`, `tugas`, `status_tugas_siswa`) + FK/Index/Constraint + trigger anti-duplikat & anti-bentrok jadwal.

### 3. Storage Bucket
**Storage** → **New Bucket** → `lampiran-tugas` → **Public = true**.  
Policies ada di komentar migration — `insert` hanya untuk `authenticated`, `select` untuk public/anon sesuai tugas published.

### 4. Akun Admin Pertama
```sql
-- 1) Authentication → Users → Add user (misal admin@sekolah.id / password)
-- 2) Ambil UUID-nya, jalankan:
insert into public.profiles (id, full_name, email, role, is_active)
values ('<uuid-dari-auth.users>', 'Administrator', 'admin@sekolah.id', 'admin', true);
-- Untuk guru: role = 'guru'
```

### 5. Edge Functions (wajib untuk undang guru & status tugas online)
```bash
npm i -g supabase
supabase login
supabase link --project-ref <project-ref>

# create-teacher: JWT diverifikasi gateway (verify_jwt=true di supabase/config.toml)
supabase functions deploy create-teacher

# Endpoint siswa: verify_jwt=false di config.toml (siswa tidak login)
supabase functions deploy student-access
supabase functions deploy update-student-task-status
```

`supabase/config.toml` sudah menetapkan `verify_jwt` per function, jadi **tidak perlu** flag
`--no-verify-jwt` untuk `create-teacher`. Jika project ini sebelumnya men-deploy dengan
`--no-verify-jwt` dan ingin mengembalikan proteksi gateway, jalankan ulang perintah deploy di atas.

Secret yang dibutuhkan function (Dashboard → **Edge Functions** → **Secrets**, jangan commit nilainya):
- `SUPABASE_URL` — URL project yang **sama** dengan `--dart-define=SUPABASE_URL` saat build APK
- `SUPABASE_SERVICE_ROLE_KEY` — hanya untuk server (function). Fallback nama `SERVICE_ROLE_KEY` juga didukung.
- `SUPABASE_ANON_KEY` — tidak lagi dibutuhkan oleh `create-teacher` versi ini (tidak ada lagi ketergantungan pada anon key untuk verifikasi token).

> **Penting:** function harus berada di project yang sama dengan URL/anon key yang dipakai APK.
> Jika berbeda, token admin tidak dikenali dan function membalas **401**.

**Deploy lewat GitHub Actions (opsional):** jalankan workflow **Deploy Supabase Edge Functions**
(Actions → Run workflow) setelah menambahkan Secrets `SUPABASE_ACCESS_TOKEN` dan
`SUPABASE_PROJECT_REF`. Workflow ini manual, tidak jalan otomatis ke produksi.

#### Uji cepat Edge Function tanpa Flutter (opsional)
```bash
SUPABASE_URL="https://xxxx.supabase.co" \
SUPABASE_ANON_KEY="<anon/publishable key>" \
ADMIN_EMAIL="admin@sekolah.id" ADMIN_PASSWORD="<password admin>" \
node scripts/test-create-teacher.mjs
```
Script menguji: request tanpa token → 401, token palsu → 401, login admin, dan (bila
`GURU_EMAIL`/`GURU_PASSWORD` diisi) guru non-admin → 403. Tambahkan `CREATE_TEST_TEACHER=1`
hanya jika ingin benar-benar membuat akun guru uji. Script tidak mencetak token/secret.

#### Diagnosis 401 `create-teacher`
Balasan function `{"error":"Unauthorized"}` (persis seperti di aplikasi) berasal dari
**verifikasi token di dalam function**, bukan dari gateway — artinya function sudah berjalan
tetapi `auth.getUser(token)` menolak token admin. Penyebab yang mungkin:

| Gejala | Arti | Tindakan |
|---|---|---|
| 401 `{error: "Unauthorized ..."}` | Token admin tidak valid/kedaluwarsa, atau ditandatangani project lain | Login ulang (client kini me-refresh token otomatis), samakan `SUPABASE_URL` APK dengan project function |
| 401 `{code: 401, message: "Invalid JWT"}` | Ditandatangani/ditolak gateway | Sama seperti di atas; pastikan `verify_jwt=true` pada project yang benar |
| 403 `{error: "Forbidden ..."}` | Token valid, tapi `profiles.role != admin` atau `is_active != true` | Perbaiki baris `profiles` |
| 404 | Function belum dideploy | `supabase functions deploy create-teacher` |
| 500 `server_misconfigured` | Secret server belum ada **atau** `SUPABASE_SERVICE_ROLE_KEY` berasal dari project lain | Set `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` dari project yang sama |

> Aplikasi **tidak** mematikan verifikasi dan **tidak** memakai `service_role` di client.
> `service_role` hanya dipakai di dalam Edge Function.

---

## 🚀 Menjalankan di Laptop

```bash
git clone https://github.com/HOOOOOOQ/aplikasioo.git
cd aplikasioo
flutter pub get

# Dengan Supabase (Wajib untuk data real):
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGc...

# Tanpa config — mode DEMO (UI jalan, data kosong, tampil EmptyState + banner warning):
flutter run
```

`main.dart` sudah guard: `SupabaseConfig.isConfigured` → `Supabase.initialize(...)` di `try/catch`, `tz.initializeTimeZones()` + `initializeDateFormatting('id_ID')` di `try/catch`, `NotificationService.init()` di `try/catch`, `FlutterError.onError` global handler — tidak FC diam-diam.

**VS Code** `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "EduTask (dev)",
      "request": "launch",
      "type": "dart",
      "toolArgs": [
        "--dart-define=SUPABASE_URL=https://xxx.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOi..."
      ]
    }
  ]
}
```

---

## 🧪 Test & Analyze

```bash
flutter analyze          # harus 0 issue (flutter_lints 4.0)
flutter test
flutter test --coverage
```
Test meliputi: `deadline logic` (selesai/terlambat/mendekati), format tanggal & hari Indonesia, role mapping, akses publik siswa, validasi RLS.

CI (GitHub Actions) menjalankan `flutter analyze` + `flutter test` sebelum build — build gagal jika analyze/test merah.

---

## 🏗️ Build APK — GitHub Actions

Workflow: `.github/workflows/build-apk.yml` — trigger `push` ke `main` + manual `workflow_dispatch`.

Langkah CI (Ubuntu, Java 17, Flutter stable 3.35.4, Gradle 8.13):
1. Checkout + setup Java 17 + setup Gradle 8.13
2. Setup Flutter `stable` → `flutter pub get`
3. `dart format --set-exit-if-changed .` (check)
4. `flutter analyze`
5. `flutter test`
6. `flutter build apk --release` — plus `with --dart-define` job bila Secrets `SUPABASE_URL`/`SUPABASE_ANON_KEY` ada
7. `upload-artifact` — `edutask-release-apk` (`build/app/outputs/flutter-apk/app-release.apk`, ~29MB) + `build-log`

**Download APK:**
Repo → **Actions** → workflow **Build EduTask APK** hijau → **Artifacts** → `edutask-release-apk` → unzip → `app-release.apk` → install di Android (izinkan *Install from unknown sources* untuk Chrome/Files).

**Build lokal:**
```bash
flutter build apk --release
# atau
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

**Signing release (Play Store):**
Jangan commit keystore. Buat lokal:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Buat `android/key.properties` (sudah di `.gitignore`):
```
storeFile=upload-keystore.jks
storePassword=xxx
keyAlias=upload
keyPassword=xxx
```
Untuk CI: simpan `KEYSTORE_BASE64` (`base64 -w 0 upload-keystore.jks`), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` sebagai **GitHub Secrets** lalu decode sebelum build di workflow.

> APK debug/release tanpa keystore production tetap **bisa install** (pakai `signingConfig debug` sebagai fallback) — sudah dibuktikan build CI 29MB sukses. Untuk Play Store wajib signing upload key.

---

## 🔐 Cara Tambah GitHub Secrets (opsional)

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:
- `SUPABASE_URL` — dipakai job build *with* Secrets
- `SUPABASE_ANON_KEY`
- `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` — untuk signing produksi

Tanpa secrets, job *without* secrets tetap build demo APK (tidak error `SUPABASE_* not set`).

---

## 🔔 Notifikasi Tenggat

- Warna deadline otomatis (`DeadlineHelper` + `AppDateUtils`):
  - 🟢 `success` — tugas sudah ditandai selesai
  - 🟠 `warning` — tenggat <24 jam (`deadlineWarningHours = 24`)
  - 🔴 `error` — sudah lewat tenggat
  - 🔵 `primary` — masih aktif
- `AppDateUtils.nowJakarta()` & `toJakarta()` pakai `timezone` `Asia/Jakarta` — aman meski device di zona lain
- Notifikasi lokal via `flutter_local_notifications` (`NotificationService.scheduleForTugas`):
  - Trigger 24 jam & 1 jam sebelum tenggat
  - Permission Android: `POST_NOTIFICATIONS` (runtime Android 13+), `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` (Android 12+), `RECEIVE_BOOT_COMPLETED` — sudah di `AndroidManifest.xml`
  - Permission runtime diminta pakai `permission_handler`/`flutter_local_notifications` request — jika ditolak, tampil penjelasan, tidak FC
  - **Catatan:** butuh app pernah dibuka & izin diberikan; tidak 100% terjamin bila battery optimization agresif — test di device fisik, bukan emulator.

---

## 🛡️ Keamanan

- **Tidak ada `service_role` di APK** — hanya `anonKey` via `--dart-define` (aman di `SupabaseConfig.fromEnvironment`)
- `create-teacher`: identitas admin diambil **hanya** dari bearer token yang diverifikasi ke GoTrue (`auth.getUser(token)`), role dibaca dari `profiles` memakai service_role di server; input divalidasi; duplikasi email ditolak (409); jika insert profil gagal, user Auth di-rollback
- RLS aktif di semua tabel; `profiles.role` diverifikasi server, bukan dari client
- Siswa anon hanya `SELECT` jadwal/tugas `published` + daftar kelas/mapel; tidak bisa insert/update langsung
- Status tugas via Edge Function + validasi `kode_akses` + kecocokan `kelas_id` + token akses; fallback lokal dijelaskan sebagai *tidak resmi*
- `SupabaseService`: `isReady`, `tryClient`, `tryAuth`, `currentUser`, `isLoggedIn`, `signOut()` — tidak throw bila belum ready; `client` getter throw dengan pesan jelas bila lupa guard
- `main.dart` + semua repository method sudah `try/catch` — error tampil `ErrorState`/`SnackBar`, bukan force close

---

## 🧩 Struktur Folder

```
lib/
  main.dart                         # guard tz/intl/supabase/notification + FlutterError
  app.dart                          # MaterialApp.router + GoRouter (splash→login/admin/guru, siswa publik)
  core/
    config/supabase_config.dart     # isConfigured/isNotConfigured, dart-define
    config/app_constants.dart
    constants/app_colors.dart        # biru utama (#0D47A1), hijau/oranye/merah status
    constants/app_theme.dart         # Material3, card bulat (16), bottomNav, drawer
    routing/app_router.dart
    utils/{date_utils,deadline_helper,validators,file_utils}.dart
    widgets/{app_banner,empty_state,loading_view,status_chip,confirm_dialog}.dart
  features/
    auth/{data,presentation}        # login, auth_provider, role redirect
    admin/presentation/pages/*      # dashboard, students, teachers, classes, subjects, schedules, tasks, reports
    teacher/presentation/pages/*    # dashboard, schedules, tasks, task_form, task_status
    student/{presentation,identity} # main, schedule, task_list, task_detail, identity (kode)
    notifications/notification_service.dart
  shared/
    models/{kelas,siswa,jadwal,mata_pelajaran,tugas,status_tugas}.dart
    repositories/{kelas,siswa,jadwal,mapel,tugas}_repository.dart
    services/supabase_service.dart
supabase/
  config.toml                        # verify_jwt per Edge Function
  migrations/001_initial_schema.sql  # 8+ tabel + RLS + trigger
  functions/{create-teacher,student-access,update-student-task-status}/index.ts
.github/workflows/build-apk.yml
android/                            # compileSdk 36, mipmap icons dari logo
assets/images/{edutask_logo.png,edutask_banner.png}
test/                               # deadline, date, role, RLS, akses publik
```

---

## 🐛 Troubleshooting Lengkap

| Masalah | Solusi |
|---|---|
| `Supabase belum dikonfigurasi` / data kosong | Jalankan dengan `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Cek `lib/core/config/supabase_config.dart`. |
| `Failed host lookup` / tidak ada koneksi | Cek internet & URL `https://...supabase.co` (tanpa trailing slash). |
| Login gagal `Invalid login credentials` | Pastikan user ada di **Auth → Users** DAN ada baris di `profiles` dengan `role` `admin`/`guru` & `is_active=true`. |
| `force close` saat buka halaman siswa | Sudah di-fix: semua repository `return []` bila `!isReady`, UI `try/catch`. Jika masih, cek `flutter analyze` & laporkan log `adb logcat`. |
| Undang guru gagal `HTTP 401` | **Sesi admin tidak valid** atau **function ada di project berbeda**. Aplikasi otomatis me-refresh token sebelum memanggil function; jika tetap 401: (1) logout → login ulang sebagai admin, (2) pastikan `--dart-define=SUPABASE_URL`/`ANON_KEY` APK = project tempat function dideploy, (3) redeploy `supabase functions deploy create-teacher` (lihat §5). Detail penyebab kini tampil di dialog, bukan pesan generik. |
| Undang guru gagal `HTTP 403` | User login valid tetapi bukan admin aktif. Cek `select id,email,role,is_active from profiles;` → baris admin harus `role='admin'`, `is_active=true`. |
| Undang guru gagal `HTTP 404` | Function belum ada di project. Jalankan `supabase functions deploy create-teacher`. |
| Undang guru gagal `HTTP 500` | Secret `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` belum ter-set di Edge Functions → Secrets, atau migration `profiles` belum dijalankan. |
| Undang guru gagal (lainnya) | Deploy Edge Function `create-teacher` + isi Secrets `SUPABASE_SERVICE_ROLE_KEY`. Tanpa itu, aplikasi menampilkan error yang dapat ditindaklanjuti (bukan FC). |
| Jadwal bentrok | Constraint DB mencegah overlap kelas/guru di hari & jam sama — ubah jam atau ruang. |
| Upload lampiran gagal `bucket not found` | Buat bucket `lampiran-tugas` public + policy `insert` untuk `authenticated`. |
| `There was a problem parsing the package` saat install APK | Android 12+ wajib `android:exported="true"` pada activity dengan intent-filter — sudah di `AndroidManifest.xml`. Juga cek *Install unknown apps* diizinkan untuk Chrome/Files di **Settings → Apps → Special access**. Uninstall APK debug lama jika ganti signature. |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | Build default arm64; test di device arm64/x86_64. Emulator x86 murni tidak support release APK. |
| `Build APK gagal: Java version` | Pakai **Java 17** (Temurin) — AGP 8.11.1 + Gradle 8.13 butuh Java 17, bukan 8/11/21. |
| `kernel_snapshot failed: No such file supabase_config.dart` | Path import harus `../../../core/config/supabase_config.dart` (3 level dari `features/auth/presentation`) — sudah fix di commit `815949b`. |
| `mipmap ic_launcher broken` | Sudah regenerate 5 density PNG dari `edutask_logo.png` (bukan 68B placeholder). |
| Notifikasi tidak muncul | Cek permission `POST_NOTIFICATIONS` (Android 13+) di Settings → Apps → EduTask → Notifications → Allow. Test di device fisik (banyak emulator matikan alarm). |

---

## 📄 Lisensi

MIT — bebas dipakai untuk pendidikan.

## 🤝 Kontribusi

PR welcome! Pastikan `flutter analyze` & `flutter test` hijau sebelum PR.

---

*Built with ❤️ by PALL — terima kasih atas dedikasi dari kode rapi sampai eksekusi UI/UX yang mulus.*

