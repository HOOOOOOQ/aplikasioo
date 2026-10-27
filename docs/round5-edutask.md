# Ronde 5 — Total Bug Fix, Redesign Modern, Web & 25+ Fitur

Dokumen ini adalah laporan kerja ronde 5 untuk **EduTask** (`HOOOOOOQ/aplikasioo`).
Semua klaim di bawah dipisahkan menjadi tiga status supaya tidak ada yang
dilebih-lebihkan:

| Status | Arti |
|---|---|
| **SELESAI (kode)** | Perubahan sudah ada di repo, lolos pemeriksaan sintaks/statis lokal. |
| **TERVERIFIKASI CI** | Ditandai hanya setelah `flutter analyze` / `flutter test` / build berjalan di GitHub Actions. |
| **BELUM TERVERIFIKASI** | Butuh perangkat, Supabase live, atau toolchain yang tidak tersedia di lingkungan kerja ini. |

> Lingkungan kerja ronde ini **tidak memiliki** Flutter SDK, Dart SDK, JDK,
> Android SDK, `adb`, `apksigner`, maupun akses ke project Supabase. Karena itu
> seluruh validasi kode memakai pemeriksaan statis (parser Dart/TypeScript dan
> parser SQL) dan validasi runtime menunggu CI serta pengujian manual.

---

## 1. Ringkasan

Ronde 5 **tidak membangun ulang aplikasi dari nol**. Seluruh pekerjaan dilakukan
di atas basis ronde 4 (`2e71ddd`) dengan pendekatan: audit → reproduksi lewat
kode/log → diagnosis akar masalah → perbaikan bertahap → build/validasi.

Fokus ronde 5:

1. **Flutter Web benar-benar bisa dibangun** — sebelumnya folder `web/` kosong
   sehingga `flutter build web` tidak mungkin berhasil.
2. **Pemisahan platform** untuk plugin yang tidak ada di browser (notifikasi
   lokal, penjadwalan alarm, penyimpanan berkas).
3. **Penyelesaian fitur** yang sebelumnya hanya setengah ada (pengaturan
   bersama, bantuan/FAQ, guru kelas, kalender tenggat, riwayat kode, sesi
   perangkat, ekspor CSV).
4. **Onboarding 8 langkah** sesuai spesifikasi ronde 5 (sebelumnya 5 langkah).
5. **Perbaikan bug nyata** yang ditemukan saat audit (lihat bagian 3).

---

## 2. Root cause bug yang ditemukan & diperbaiki

### 2.1 `web/` kosong → Web tidak mungkin dibangun (BLOCKER)

* **Gejala:** `flutter build web` gagal / `flutter run -d web-server` tidak
  menghasilkan apa pun; tidak ada `index.html`, manifest, maupun ikon.
* **Akar masalah:** folder `web/` dibuat tetapi tidak pernah diisi; bootstrap
  `flutter_bootstrap.js` tidak punya halaman induk.
* **Perbaikan:** `web/index.html` (splash HTML, tema `#1A56DB`, event
  `flutter-first-frame`, `prefers-reduced-motion`), `web/manifest.json` (PWA,
  4 ikon termasuk *maskable*), `web/icons/*`, `web/favicon.png`,
  `web/_redirects`, `web/404.html`.
* **Bukti:** `ls web/` → 7 berkas (sebelumnya kosong).

### 2.2 Plugin Android dipanggil tanpa syarat di kode lintas platform

* **Gejala (potensial):** `MissingPluginException` / gagal kompilasi Web karena
  `flutter_local_notifications` diimpor langsung.
* **Akar masalah:** `NotificationService` mengimpor plugin native secara
  langsung dan dipanggil dari `main()`, halaman pengaturan, dan pengaturan
  bersama. Di Web plugin tersebut tidak punya implementasi.
* **Perbaikan:**
  * `notification_backend_native.dart` (Android/iOS: `zonedSchedule` dengan
    fallback *exact → inexact*, izin runtime Android 13+, `DarwinNotificationDetails`),
  * `notification_backend_stub.dart` (tanpa plugin, semua operasi no-op),
  * `notification_service.dart` memilih backend lewat
    `if (dart.library.io)` dan mengekspos `isSupported` + `availabilityNote`.
* **Bukti:** `grep -rn "flutter_local_notifications" lib` hanya muncul di
  berkas `*_native.dart`.

### 2.3 URL Web tidak diatur → refresh/Back pada rute dalam menghasilkan 404

* **Akar masalah:** belum ada strategi URL; Flutter Web default memakai hash,
  tetapi tidak ada kode yang memilih strategi secara eksplisit, dan `_redirects`
  belum ada.
* **Perbaikan:** `url_strategy.dart` + `_web.dart` + `_stub.dart`
  (`flutter_web_plugins`), default **hash** (`/#/admin`) agar bekerja di semua
  static host; path strategy opt-in `--dart-define=USE_PATH_URL_STRATEGY=true`
  dengan `web/_redirects` siap pakai.

### 2.4 Dobel bilah judul (AppBar ganda) pada sub-halaman baru

* **Akar masalah:** `AdminShell`/`TeacherShell` selalu membuat AppBar, sementara
  sub-halaman (riwayat kode, bantuan, sesi) juga punya AppBar sendiri.
* **Perbaikan:** shell melewatkan AppBar-nya untuk tiga rute tersebut
  (`/admin/riwayat-kode`, `/admin/bantuan`, `/admin/sesi`, dan pasangan
  `/guru/...`) sehingga hanya satu bilah judul tampil dan tombol Back berfungsi.

### 2.5 Tutorial bisa melempar pengguna ke halaman login

* **Akar masalah:** `_finish()` selalu `context.go('/login')` bila halaman
  dibuka dengan `go` (bukan `push`). Saat tutorial diputar ulang dari
  **Pengaturan**, pengguna yang sudah login terlempar keluar dari dashboard.
* **Perbaikan:** rute asal dikirim sebagai `?from=/admin|/guru|/siswa`;
  `_finish()` kembali ke rute itu (validasi hanya path internal yang diawali
  satu `/`). Membuka dari halaman login tetap memakai `push` → `pop`.

### 2.6 Aset suara bisa memicu assert di iOS

* **Akar masalah:** `AudioContextIOS(category: ambient, options: {mixWithOthers})`
  — audioplayers hanya mengizinkan `mixWithOthers` eksplisit untuk kategori
  `playback`/`playAndRecord`/`multiRoute`.
* **Perbaikan:** kategori `ambient` saja (kategori ini sudah otomatis bercampur),
  plus fallback zona waktu `Asia/Jakarta → tz.local → UTC`.

### 2.7 Pengingat tenggat tidak pernah dijadwalkan

* **Akar masalah:** `NotificationService.scheduleUpcoming()` ada, tetapi tidak
  ada satu pun pemanggil — fitur "pengingat" hanya UI.
* **Perbaikan:** dijadwalkan sekali per kunjungan halaman Daftar Tugas siswa
  setelah data server berhasil dimuat, mengikuti preferensi
  `deadlineReminders`. Di Web tidak memanggil apa pun (backend stub).

### 2.8 Skala teks menimpa pengaturan aksesibilitas OS

* **Akar masalah:** `MediaQuery.textScaler` diganti dengan nilai preferensi saja.
* **Perbaikan:** skala akhir = `skala OS × preferensi`, dijepit `0.8–2.0`;
  preferensi sendiri dijepit `0.9–1.4` saat disimpan (`AppPreferences.clampTextScale`).
  `NaN`/`Infinity` dikembalikan ke `1.0`.

---

## 3. Daftar file yang berubah

### 3.1 Berkas baru (Flutter)

| Berkas | Isi |
|---|---|
| `lib/core/services/platform_capabilities.dart` | Deteksi Web/Android/iOS + kapabilitas fitur |
| `lib/core/services/csv_builder.dart` | Pembentuk CSV (RFC 4180 + anti formula-injection) |
| `lib/core/services/csv_saver.dart` / `_native.dart` / `_stub.dart` | Simpan CSV (native) / stub (Web) |
| `lib/core/widgets/csv_export_sheet.dart` | Sheet pratinjau + salin + simpan CSV |
| `lib/core/routing/url_strategy.dart` / `_web.dart` / `_stub.dart` | Strategi URL Web |
| `lib/features/notifications/notification_backend_native.dart` | Backend notifikasi Android/iOS |
| `lib/features/notifications/notification_backend_stub.dart` | Backend no-op (Web) |
| `lib/core/widgets/app_preferences_section.dart` | Pengaturan bersama admin/guru/siswa |
| `lib/features/help/presentation/help_page.dart` | Bantuan & FAQ per peran |
| `lib/features/akademik/presentation/guru_kelas_page.dart` | Daftar guru kelas + tombol chat |
| `lib/features/akademik/presentation/tenggat_page.dart` | Kalender tenggat tugas |
| `lib/features/access_codes/presentation/access_code_history_page.dart` | Riwayat kode akses (RPC `kode_akses_riwayat`) |
| `lib/features/auth/presentation/session_page.dart` | Informasi sesi + keluar dari semua perangkat |
| `test/core/csv_builder_test.dart` | 11 pengujian CSV |
| `test/core/app_preferences_test.dart` | 6 pengujian preferensi & clamp teks |
| `test/core/platform_capabilities_test.dart` | 4 pengujian kapabilitas platform |
| `web/index.html`, `web/manifest.json`, `web/_redirects`, `web/404.html`, `web/favicon.png`, `web/icons/*` | Scaffold Flutter Web + PWA |

### 3.2 Berkas yang diubah

| Berkas | Perubahan |
|---|---|
| `lib/main.dart` | URL strategy, init notifikasi hanya bila didukung, guard error |
| `lib/app.dart` | Skala teks (OS × preferensi), banner mode terbatas non-blocking, layout desktop 960 px |
| `lib/core/routing/app_router.dart` | Rute baru: `/bantuan`, `/siswa/tenggat`, `/siswa/guru`, `/siswa/bantuan`, `/admin|guru/riwayat-kode`, `/admin|guru/bantuan`, `/admin|guru/sesi` |
| `lib/core/services/app_preferences.dart` | `chatNotifications`, `textScale`, clamp, key baru |
| `lib/core/services/welcome_sound.dart` | Perbaikan konteks audio iOS |
| `lib/core/widgets/app_preferences_section.dart` | Bagian pengaturan bersama + replay tutorial |
| `lib/features/onboarding/presentation/onboarding_page.dart` | 8 langkah + kembali ke rute asal |
| `lib/features/auth/presentation/login_page.dart` | Tautan Bantuan + versi dari metadata |
| `lib/features/access_codes/presentation/access_codes_page.dart` | Tombol riwayat kode + pencarian sejajar |
| `lib/features/admin/presentation/pages/admin_reports_page.dart` | Ekspor CSV laporan |
| `lib/features/admin/presentation/pages/admin_shell.dart` | Suppress AppBar pada sub-halaman |
| `lib/features/admin/presentation/pages/admin_settings_page.dart` | Rute bantuan di pengaturan bersama |
| `lib/features/student/presentation/pages/student_main_page.dart` | Tombol Tenggat, Guru Kelas, Bantuan |
| `lib/features/student/presentation/pages/student_settings_page.dart` | Rute bantuan |
| `lib/features/student/presentation/pages/student_task_list_page.dart` | Penjadwalan pengingat tenggat |
| `lib/features/teacher/presentation/pages/teacher_profile_page.dart` | Rute bantuan |
| `lib/features/teacher/presentation/pages/teacher_shell.dart` | Suppress AppBar pada sub-halaman |
| `lib/features/notifications/notification_service.dart` | Ditulis ulang memakai backend terpisah |
| `pubspec.yaml` | `flutter_web_plugins` (paket SDK) |
| `test/features/onboarding_test.dart` | Disesuaikan dengan 8 langkah (bukan dihapus) |
| `README.md` | Bagian Web, migrasi 006, Edge Functions baru |

---

## 4. Migrasi SQL

**Ronde 5 tidak menambah migrasi baru.** Audit menemukan tidak ada tabel yang
perlu dibuat:

* Riwayat kode akses memakai RPC `kode_akses_riwayat(int)` yang sudah ada di
  `supabase/migrations/006_round4_academic_chat.sql`.
* Audit log memakai tabel `public.audit_log` + trigger dari
  `supabase/migrations/004_access_codes_audit.sql` (kebijakan baca hanya
  `is_admin()`), sehingga tidak ada tabel duplikat.
* Kebutuhan Web (sesi di `localStorage`, penyimpanan berkas) tidak menyentuh
  skema database.

Migrasi 001–006 tetap idempoten dan non-destruktif; pemeriksaan parser SQL:
**6/6 file berhasil diparse tanpa error**.

Bila RPC `kode_akses_riwayat` belum ada di project Supabase tertentu (mis. 006
belum dijalankan), halaman Riwayat menampilkan pesan error yang bisa
ditindaklanjuti, bukan layar kosong.

---

## 5. RLS & Storage

Tidak ada RLS yang dilemahkan dan tidak ada bucket yang dijadikan publik pada
ronde ini. Status yang berlaku:

| Area | Kebijakan | Status |
|---|---|---|
| `kode_akses_siswa` | Admin semua baris; guru hanya kelas yang diampu; siswa tidak punya akses baca daftar | Tidak diubah (006) |
| `audit_log` | `select` hanya `is_admin()`; `anon` dicabut | Tidak diubah (004) |
| Chat/pengumuman/kalender/notifikasi | RLS per anggota percakapan & kelas | Tidak diubah (006) |
| Storage `lampiran-tugas` | Bucket privat, policy per path `tugas/<guru_id>/<tugas_id>/<file>` | Tidak diubah (003) |

Karena project Supabase tidak dapat diakses dari lingkungan ini, **status
runtime RLS tetap BELUM TERVERIFIKASI**; yang bisa dinyatakan adalah tidak ada
perubahan yang memperlemah policy.

---

## 6. Edge Functions & RPC

| Nama | Jenis | Dipakai oleh ronde 5 |
|---|---|---|
| `student-chat` (`guru_list`, thread, pesan, unread) | Edge Function | Halaman **Guru Kelas** siswa |
| `student-portal` | Edge Function | Pengumuman, kalender, tugas, notifikasi siswa (ronde 4) |
| `student-access` | Edge Function | Verifikasi kode akses |
| `student-codes` | Edge Function | Terbit/cabut kode akses |
| `kode_akses_riwayat(p_limit)` | RPC | Halaman **Riwayat Kode Akses** |
| `kode_akses_stats()` | RPC | Statistik halaman Kode Akses |
| `edutask_schema_health()` | RPC | Diagnostik admin |

Tidak ada `service_role` di aplikasi, bundle, maupun repo.

---

## 7. Fitur yang benar-benar selesai

Tanda: **K** = kode tersedia & terhubung ke UI, **C** = sudah pernah lolos CI
pada ronde sebelumnya (mis. 140 test ronde 4), **M** = perlu uji manual di
perangkat/Supabase.

| # | Fitur | Status | Bukti |
|---|---|---|---|
| 1 | Statistik dashboard admin/guru | K, C | `admin_dashboard_page.dart`, `akademikStatsProvider` |
| 2 | Kalender akademik | K, C | `kalender_page.dart` |
| 3 | Jadwal pelajaran | K, C | `admin_schedules_page.dart`, `student_schedule_page.dart` |
| 4 | Pengingat tenggat | K (baru tersambung) | `NotificationService.scheduleUpcoming` dari daftar tugas |
| 5 | Filter status tugas | K, C | `student_task_list_page.dart` |
| 6 | Status tugas resmi (kode akses) | K, C | `student-portal`/`status_tugas_siswa` |
| 7 | Pengumpulan tugas + revisi + nilai | K | `006`, `student-portal` |
| 8 | Riwayat & umpan balik | K | detail tugas siswa |
| 9 | Lampiran tugas (validasi tipe/ukuran) | K, C | `attachment_service.dart`, `003` |
| 10 | Chat pribadi siswa↔guru | K | `student-chat` |
| 11 | Grup kelas | K | `chat_threads_page.dart` |
| 12 | Pengumuman per kelas | K | `pengumuman_page.dart` |
| 13 | Guru per kelas | **K (baru)** | `guru_kelas_page.dart` + `guru_list` |
| 14 | Mata pelajaran | K, C | `admin_subjects_page.dart` |
| 15 | Profil pengguna | K, C | `teacher_profile_page.dart`, `student_settings_page.dart` |
| 16 | Kode akses: terbit, kedaluwarsa, cabut, sekali pakai | K, C | `access_codes_page.dart`, `student-codes` |
| 17 | Riwayat kode akses | **K (baru)** | `access_code_history_page.dart` |
| 18 | Laporan penyelesaian | K, C | `admin_reports_page.dart` |
| 19 | Ekspor CSV laporan | **K (baru)** | `csv_builder.dart`, `csv_export_sheet.dart` |
| 20 | Pencarian global | K | `pencarian_page.dart` |
| 21 | Pusat notifikasi | K | `notifikasi_page.dart` |
| 22 | Mode gelap | **Tidak diaktifkan (disengaja)** | lihat bagian 11 |
| 23 | Ukuran teks / aksesibilitas | **K (baru)** | slider 90–140 %, clamp aman |
| 24 | Tutorial onboarding | **K (8 langkah)** | `onboarding_page.dart` |
| 25 | FAQ/Bantuan | **K (baru)** | `help_page.dart` |
| 26 | Health check skema | K, C | `schema_health.dart` |
| 27 | Indikator sinkronisasi | K | `app_banner.dart`, `dashboard_health` |
| 28 | Manajemen sesi | **K (baru)** | `session_page.dart` (`signOut(global)`) |
| 29 | Audit log | K | `admin_audit_page.dart`, `audit_log` |
| 30 | Filter laporan per kelas | K, C | `admin_reports_page.dart` |
| 31 | Kalender tenggat | **K (baru)** | `tenggat_page.dart` |
| 32 | Preferensi notifikasi chat | **K (baru)** | `app_preferences_section.dart` |
| 33 | Tentang (tim, sekolah, Instagram, slogan) | K, C | `about_page.dart` |

Fitur yang **belum** dikerjakan dan tidak diklaim selesai:
**PDF laporan** (butuh paket tambahan + uji cetak) dan **pin tugas** (tidak ada
kolom/UI yang disetujui). Keduanya dicatat di bagian 12.

---

## 8. Hasil `flutter analyze` — TERVERIFIKASI CI

Dijalankan oleh workflow **Verify Flutter** di GitHub Actions (Flutter 3.35.4):

```
Analyzing aplikasioo...
   info • use_build_context_synchronously • lib/core/navigation/back_guard.dart:184:41
   info • use_build_context_synchronously • lib/core/navigation/back_guard.dart:186:17
   info • prefer_initializing_formals     • lib/core/services/session_guard.dart:49:9
   info • prefer_initializing_formals     • lib/core/services/session_guard.dart:58:9
4 issues found.
```

**0 error, 0 warning.** Empat `info` di atas adalah temuan lama (berkas ronde 4)
yang tidak diubah pada ronde ini; CI memakai `--no-fatal-infos`.

Pemeriksaan tambahan di lingkungan tanpa SDK:

* parser Dart (tree-sitter) untuk `lib/` + `test/`: **131 berkas, 0 error sintaks**;
* pemindaian import tak terpakai: **0 temuan**;
* koreksi API yang ditemukan lewat audit: `AppHeroHeader` tanpa `icon`,
  `DeadlineHelper.getStatus(deadline:, isCompleted:)`, `AppRadius` →
  `AppSpacing.radiusMd`, `Tugas.tenggatWaktu` non-null, `AkademikAudience`
  & `UserRoleX.label` yang belum diimpor.

## 9. Hasil `flutter test` — TERVERIFIKASI CI

```
🎉 162 tests passed.
```

- Sebelumnya 140 test (ronde 4) → **162 test** pada ronde 5 (+22).
- Pengujian baru: CSV (11), preferensi teks (6), kapabilitas platform (4),
  onboarding 8 langkah (diperbarui, bukan dihapus).
- Satu kegagalan awal (`label platform` berbeda kapitalisasi di lingkungan
  test) diperbaiki pada penyebabnya — bukan dengan menghapus test.

## 10. Build APK — TERVERIFIKASI CI

Workflow **Build EduTask APK** berhasil pada PR ini (**build #83**), termasuk
job **install-test di emulator Android x86_64** yang memasang APK dan melakukan
*cold start* (status job: **SUCCESS**).

| Item | Nilai |
|---|---|
| Berkas | `EduTask-1.2.0-arm64-v8a.apk` (disarankan), `armeabi-v7a`, `x86_64`, `universal` |
| Ukuran | 26 MB / 24 MB / 27 MB / 65 MB |
| SHA-256 (arm64) | `2ee70a109a4fb1477df30a940a5ff2337aab6ed6e34745abaabef3f5febb8b14` |
| SHA-256 (armeabi-v7a) | `202b6aefee283dea2f390c290d8d981912337054f330e1b740f3045f46ad7919` |
| SHA-256 (x86_64) | `854ef5a2d675abe8e22ebe53215cd49f4bd26d176898131c89e92ddeaa10515b` |
| SHA-256 (universal) | `cfd7ff978f5082cadba34711f25a40e9e8998e955aa5348f207ab4c3b299eed4` |
| applicationId | `com.edutask.sekolah` |
| versionCode | 83 (universal) / 2083 (arm64) / 1083 (armeabi-v7a) / 4083 (x86_64) |
| versionName | `1.2.0` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| Tanda tangan | v2 + v3 **valid**, 1 signer, sertifikat `C=ID, O=EduTask Sekolah, CN=EduTask`, SHA-256 `f3d985e457b01512b34091c25826869ed48fe9efd42b988375fc401562ffcbf9` (keystore uji yang di-commit — **bukan** kunci Play Store) |
| Unduh (setelah merge) | `https://github.com/HOOOOOOQ/aplikasioo/releases/tag/latest-apk` |

Catatan: workflow hanya mempublikasikan APK ke Release pada push ke `main`
(`github.event_name != 'pull_request'`). Sebelum merge, APK ronde 5 tersedia
sebagai artifact job `build` pada PR, sedangkan Release `latest-apk` masih
berisi build #80 (ronde 4). Setelah merge, Release akan diperbarui otomatis.

## 11. Build Web

Job **`web-build`** ditambahkan ke workflow `verify.yml` sehingga
`flutter build web --release` benar-benar dijalankan di CI (bukan hanya
dibaca dari kode). Job tersebut:

1. `flutter pub get`,
2. `flutter build web --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
   (nilai *placeholder* publik; tidak ada kredensial asli di artifact),
3. memeriksa artefak wajib: `index.html`, `manifest.json`,
   `flutter_bootstrap.js`, `main.dart.js`, `flutter_service_worker.js`,
   `icons/Icon-192.png`,
4. memastikan kata `service_role` **tidak** muncul di bundle,
5. mengunggah `build/web` sebagai artifact (retensi 7 hari) dan menulis
   ringkasan ke komentar PR.

Perintah lokal yang setara:

```bash
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Profil basis data sesi di Web memakai `localStorage` (dikelola `supabase_flutter`),
sehingga refresh halaman tidak menghapus sesi. **Status: TERVERIFIKASI CI bila
job `web-build` pada PR berwarna hijau** (lihat komentar `### Hasil flutter build web`).

## 12. Langkah lokal (`localhost:8080`)

```bash
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

- Buka `http://localhost:8080`.
- Dari perangkat lain di LAN: `http://<IP-komputer>:8080` (pastikan firewall
  mengizinkan port 8080).
- Untuk build rilis: `flutter build web --release`, lalu sajikan `build/web`
  (`python3 -m http.server 8080 --directory build/web` untuk uji lokal).
- **Jangan** mengekspos dev server ke internet tanpa HTTPS/proxy.

## 13. Konfigurasi Supabase yang masih perlu dilakukan

1. Jalankan migrasi **001 → 006** berurutan di SQL Editor (semua idempoten).
   Ulangi `005` bila muncul error `schema cache` untuk tabel kode akses.
2. Deploy Edge Functions:
   `create-teacher`, `student-access`, `student-codes`,
   `update-student-task-status`, `student-portal`, `student-chat`.
3. Set secret function: `STUDENT_TOKEN_SECRET` (HMAC) — nilai acak ≥32 byte,
   hanya di server.
4. Pastikan bucket `lampiran-tugas` **privat** dan policy `003` terpasang.
5. Buat akun admin/guru lewat dashboard Supabase (bukan hardcoded di aplikasi),
   lalu isi `profiles.role`.
6. Untuk Web: tambahkan origin Web ke *Site URL* / *Redirect URLs* Supabase Auth
   bila memakai alur tautan surel.

## 14. Bug/keterbatasan yang belum selesai (jujur)

1. **Mode gelap** belum diaktifkan. 508 penggunaan warna `AppColors.*` bersifat
   hardcode (155 di antaranya pada baris `const`); mengaktifkan tema gelap tanpa
   migrasi token warna akan menghasilkan kontras yang salah. Nilai preferensi
   tetap disimpan agar bisa diaktifkan tanpa migrasi data.
2. **PDF laporan** belum ada (butuh paket tambahan, uji tata letak cetak, dan
   keputusan format).
3. **Pin tugas** belum ada (butuh kolom database + keputusan urutan tampil).
4. **AppBar ganda** masih terjadi pada beberapa sub-halaman lama
   (`/admin/kalender`, `/admin/chat`, `/admin/notifikasi`, `/admin/pencarian`,
   `/admin/tentang`) karena shell belum bisa mendeteksi halaman yang membawa
   AppBar sendiri secara umum. Ronde ini hanya memperbaiki tiga rute baru agar
   tidak menambah kasus baru.
5. **`kelasOptionsProvider` vs `daftarKelasProvider`** masih duplikat; belum
   digabung karena berisiko menyentuh alur data kelas yang sedang berfungsi.
6. **RLS/Storage/Edge Function** belum diuji runtime (tanpa akses Supabase).
7. **Suara pembuka di Web** kemungkinan diblokir autoplay; perilaku ini
   ditangani sebagai kegagalan senyap (tidak ada error ke pengguna).

## 15. Checklist uji manual (20 skenario wajib)

| # | Skenario | Cara uji | Hasil |
|---|---|---|---|
| 1 | Login berhasil | Login admin valid → dashboard | Belum diuji |
| 2 | Login gagal | Password salah → pesan jelas, input tetap | Belum diuji |
| 3 | Pemulihan sesi | Tutup & buka aplikasi → langsung dashboard | Belum diuji |
| 4 | Sesi kedaluwarsa | Cabut refresh token → dialog sekali, arahkan login | Belum diuji |
| 5 | Back per halaman | Back di tab, sub-halaman, dan root | Belum diuji |
| 6 | Back ganda cepat | Tekan Back 2× dalam 250 ms → satu aksi | Belum diuji |
| 7 | Buat kode akses (sukses) | Admin → Kode Akses → Terbitkan | Belum diuji |
| 8 | Buat kode gagal | Tanpa kelas / sesi habis → input tidak hilang | Belum diuji |
| 9 | Kode kedaluwarsa | Kode lewat `expires_at` → ditolak server | Belum diuji |
| 10 | Kode sudah dipakai | Pakai kode 2× → ditolak | Belum diuji |
| 11 | Kode bersamaan | Dua siswa klaim kode sama → hanya satu berhasil | Belum diuji |
| 12 | Upload lampiran | PDF 2 MB → berhasil; file 20 MB → ditolak | Belum diuji |
| 13 | Storage RLS | Akses URL lampiran tanpa sesi → 403 | Belum diuji |
| 14 | RLS per peran | Guru mencoba baca data kelas lain → kosong/ditolak | Belum diuji |
| 15 | CRUD data | Tambah/ubah/hapus kelas, mapel, jadwal | Belum diuji |
| 16 | Chat privat | Siswa A tidak bisa membaca chat siswa B | Belum diuji |
| 17 | Grup kelas | Anggota kelas melihat pesan, luar kelas tidak | Belum diuji |
| 18 | Navigasi browser | Refresh & Back pada Web di rute dalam | Belum diuji |
| 19 | Responsif | Web 360 px, 768 px, 1440 px | Belum diuji |
| 20 | Offline & audio gagal | Mode pesawat → pesan jaringan (bukan sesi habis); hapus aset audio → app tetap jalan | Belum diuji |

Catatan: skenario **instalasi APK + cold start** sudah terbukti otomatis oleh
job `install-test` (emulator Android x86_64, status SUCCESS pada build #83).
Skenario lain memerlukan akun & data pada project Supabase aktif sehingga
dibiarkan *Belum diuji* — bukan diklaim lulus.
