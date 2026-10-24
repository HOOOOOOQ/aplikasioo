# EduTask — Aplikasi Tugas dan Jadwal Pelajaran Sekolah

Aplikasi Android modern untuk mengelola tugas, jadwal pelajaran, dan laporan penyelesaian tugas dengan peran **Admin**, **Guru**, dan **Siswa** (tanpa login).

> **Package:** `com.edutask.sekolah` | **Framework:** Flutter Stable (3.24.x) | **Backend:** Supabase (PostgreSQL) | **Design:** Material 3

---

## 📸 Screenshot (Placeholder)

| Splash | Siswa Beranda | Jadwal | Tugas | Admin Dashboard | Guru Dashboard |
|---|---|---|---|---|---|
| ![splash](assets/images/splash_placeholder.png) | ![beranda](assets/images/beranda_placeholder.png) | ![jadwal](assets/images/jadwal_placeholder.png) | ![tugas](assets/images/tugas_placeholder.png) | ![admin](assets/images/admin_placeholder.png) | ![guru](assets/images/guru_placeholder.png) |

> Tambahkan screenshot asli setelah menjalankan aplikasi di emulator/device.

---

## ✨ Fitur

### 👨‍🎓 Siswa (Tanpa Login)
- Langsung masuk ke Beranda tanpa login
- Pilih kelas untuk melihat jadwal & tugas
- Jadwal: hari ini / besok / mingguan / per hari
- Tugas dengan filter: Semua, Belum selesai, Selesai, Mendekati tenggat (<24 jam), Terlambat
- Detail tugas + lampiran + informasi guru
- Tandai tugas selesai:
  - **Opsi utama:** Masukkan **kode siswa** (`SISWA-XXX`) yang diberikan sekolah → divalidasi server via Edge Function → laporan resmi ke guru
  - **Alternatif:** Tanpa kode → status disimpan lokal di perangkat (tidak menjadi laporan resmi, dijelaskan eksplisit di UI)
- Zona waktu Asia/Jakarta, sisa waktu, dan indikator warna (hijau/oranye/merah)

### 👨‍🏫 Guru (Login)
- Dashboard: jadwal hari ini, tugas aktif, mendekati tenggat, statistik penyelesaian
- Kelola tugas miliknya: tambah/edit/hapus, upload lampiran (max 10MB, pdf/doc/ppt/jpg/png/zip)
- Lihat status penyelesaian per siswa (hanya untuk tugas miliknya)
- Tidak bisa edit tugas guru lain

### 👨‍💼 Admin (Login)
- Dashboard statistik: total siswa, guru, kelas, mapel, jadwal, tugas aktif
- CRUD: Siswa (NIK unik, filter kelas), Guru (undang via Edge Function aman), Kelas, Mata Pelajaran, Jadwal (validasi bentrok kelas/guru + jam selesai > jam mulai), Tugas
- Laporan penyelesaian dengan filter kelas/guru/mapel/tanggal & persentase
- Pengaturan & status Supabase

---

## 🛠️ Teknologi

- **Flutter** 3.24.x stable, **Dart** >=3.4.0
- **State:** Riverpod 2.5.1
- **Routing:** GoRouter 14.2.7
- **Backend:** Supabase (supabase_flutter 2.5.6) — PostgreSQL + Auth + Storage + Edge Functions
- **Lainnya:** intl, shared_preferences, flutter_local_notifications, timezone, file_picker, fl_chart, cached_network_image, url_launcher, logger, gap, shimmer
- **Android:** compileSdk 34, minSdk 21, targetSdk 34, AGP 8.3.0, Gradle 8.7, Java 17, Kotlin 1.9.22

---

## 📦 Persyaratan Instalasi

- Flutter SDK stable (≥3.22.0) — [install](https://docs.flutter.dev/get-started/install)
- Dart SDK ≥3.4.0
- Android Studio atau VS Code
- Java 17 (Temurin disarankan)
- Akun Supabase (gratis) — https://supabase.com
- Git

Cek instalasi:
```bash
flutter doctor
flutter --version
java -version
```

---

## ⚙️ Cara Mengatur Supabase

### 1. Buat Proyek Supabase
1. Buka https://supabase.com/dashboard → **New Project** → nama: `EduTask`
2. Catat **Project URL** dan **anon public key** di Project Settings → API

### 2. Jalankan SQL Migration
1. Buka Supabase Dashboard → **SQL Editor** → **New query**
2. Copy-paste isi file `supabase/migrations/001_initial_schema.sql` → **Run**
3. Pastikan semua tabel & RLS policies terbuat tanpa error

### 3. Buat Storage Bucket
1. Buka **Storage** → **New Bucket** → `lampiran-tugas` → **Public bucket** = true
2. Atur policies storage (lihat komentar di file SQL migration)

### 4. Buat Admin Pertama
```sql
-- 1. Buat user via Dashboard: Authentication -> Users -> Add user (misal admin@sekolah.id)
-- 2. Jalankan di SQL Editor (ganti UUID):
insert into public.profiles (id, full_name, email, role, is_active)
values ('<uuid-dari-auth.users>', 'Administrator', 'admin@sekolah.id', 'admin', true);
```

### 5. Deploy Edge Functions (Opsional tapi disarankan)
```bash
npm install -g supabase
supabase login
supabase link --project-ref <project-ref>
supabase functions deploy create-teacher --no-verify-jwt
supabase functions deploy student-access --no-verify-jwt
supabase functions deploy update-student-task-status --no-verify-jwt
```
Set secrets di Dashboard → Edge Functions → Secrets:
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`

> Jika tidak deploy, fitur undang guru & validasi kode siswa akan fallback ke mode terbatas (lihat logs).

---

## 🚀 Cara Menjalankan Flutter di Laptop

```bash
git clone https://github.com/HOOOOOOQ/aplikasioo.git
cd aplikasioo
flutter pub get

# Jalankan dengan Supabase config (WAJIB jika sudah punya project)
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...

# Atau tanpa config untuk mode demo (data kosong, UI tetap jalan)
flutter run
```

**VS Code:** Buat `.vscode/launch.json`:
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
        "--dart-define=SUPABASE_ANON_KEY=eyJhbG..."
      ]
    }
  ]
}
```

---

## 🧪 Cara Menjalankan Test

```bash
flutter analyze
flutter test
flutter test --coverage
```

Test mencakup:
- Deadline logic (selesai/terlambat/mendekati)
- Format tanggal & hari Indonesia
- Role mapping
- Akses publik siswa tanpa login
- Validasi RLS role-based

---

## 📤 Cara Mengunggah ke GitHub

```bash
git init
git remote add origin https://github.com/HOOOOOOQ/aplikasioo.git
git add .
git commit -m "feat: EduTask v1.0.0"
git push -u origin main
```

---

## 🏗️ Cara Membangun APK via GitHub Actions

Workflow sudah ada di `.github/workflows/build-apk.yml`.

**Trigger:**
- Push ke branch `main` → otomatis build
- Atau manual: GitHub → **Actions** → **Build EduTask APK** → **Run workflow**

**Langkah Build Lokal (opsional):**
```bash
flutter build apk --release
# atau dengan config
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

**Unduh APK dari Actions:**
1. Buka repository → **Actions**
2. Pilih workflow **Build EduTask APK** yang sukses (centang hijau)
3. Scroll ke **Artifacts** → **edutask-release-apk** → Download ZIP → Extract → `app-release.apk`
4. Install di Android (izinkan "Install from unknown sources")

**Release Signing (Produksi):**
Jangan commit keystore. Buat keystore lokal:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Buat `android/key.properties` (gitignore):
```
storeFile=upload-keystore.jks
storePassword=xxx
keyAlias=upload
keyPassword=xxx
```
Untuk CI, simpan sebagai **GitHub Secrets**: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, lalu decode di workflow sebelum build.

---

## 🔐 Cara Menambahkan GitHub Secrets (jika perlu)

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:
- `SUPABASE_URL` — untuk build yang butuh env (opsional, karena --dart-define)
- `KEYSTORE_BASE64` — `base64 -w 0 upload-keystore.jks`
- Dll.

> APK debug/release tanpa signing tetap bisa diinstall untuk testing. Untuk Play Store, wajib signing.

---

## 🔔 Notifikasi Tenggat

- Indikator warna otomatis: hijau (selesai), oranye (<24 jam), merah (terlambat)
- Sisa waktu `relativeDeadline()` dengan zona Asia/Jakarta
- **Notifikasi lokal** via `flutter_local_notifications`:
  - Dijadwalkan 24 jam & 1 jam sebelum tenggat
  - Permission Android: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`
  - Panggil `NotificationService.scheduleForTugas(tugas)` setelah buat tugas
  - **Catatan:** Notifikasi terjadwal butuh app pernah dibuka & permission granted. Tidak 100% guaranteed jika battery optimization agresif — test di device fisik.

---

## 🛡️ Keamanan

- **Tidak ada service_role key di APK** — hanya anon key (publishable) via `--dart-define`
- RLS aktif di semua tabel, role diverifikasi server (`profiles.role`), bukan dari client
- Siswa anonim hanya `SELECT` jadwal/tugas published & daftar kelas
- Status tugas siswa hanya via Edge Function + validasi kode_akses & kecocokan kelas
- Fallback lokal (SharedPreferences) dijelaskan tidak resmi
- Konfirmasi dialog sebelum hapus, validasi input lengkap

---

## 🧩 Struktur Folder

```
lib/
  main.dart, app.dart
  core/{config,constants,errors,routing,theme,utils,widgets}
  features/{auth,admin,teacher,student,notifications}
  shared/{models,repositories,services}
supabase/
  migrations/001_initial_schema.sql
  functions/{create-teacher,student-access,update-student-task-status}
.github/workflows/build-apk.yml
android/
assets/
test/
```

---

## 🐛 Troubleshooting

| Masalah | Solusi |
|---|---|
| `Supabase belum dikonfigurasi` | Jalankan dengan `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` |
| `Failed host lookup` / Tidak ada koneksi | Cek internet, cek URL Supabase |
| Login gagal `Invalid login credentials` | Pastikan user ada di Auth & profiles.role terisi admin/guru & is_active=true |
| Undang guru gagal | Pastikan Edge Function `create-teacher` sudah deploy & secrets terisi |
| Jadwal bentrok error | Aturan DB mencegah overlap kelas/guru di hari & jam sama — ubah jam/ruang |
| Upload lampiran gagal | Pastikan bucket `lampiran-tugas` public & policy insert untuk authenticated |
| Build APK gagal `Java version` | Gunakan Java 17 (Temurin) sesuai AGP 8.3.0 |
| Notifikasi tidak muncul | Cek permission POST_NOTIFICATIONS & battery optimization, test di device fisik |
| `flutter analyze` error | `flutter pub get` & pastikan SDK ≥3.4.0 |

---

## 📄 Lisensi

MIT — Bebas digunakan untuk pendidikan.

---

## 🤝 Kontribusi

PR Welcome! Pastikan `flutter analyze` & `flutter test` hijau sebelum PR.

```

