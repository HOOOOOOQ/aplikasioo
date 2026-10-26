# EduTask

Aplikasi tugas & jadwal sekolah (Flutter + Supabase).

> **Ronde 2 (v1.1.0):** perbaikan akar masalah Storage 403, sistem kode akses siswa
> server-side, modul admin yang terhubung backend, dan desain ulang UI.
> Detail perubahan, status validasi, dan daftar hal yang belum diuji:
> [`docs/round2-edutask.md`](docs/round2-edutask.md).

---


Dokumen ini menjelaskan penyebab nyata, perbaikan yang sudah dilakukan di repo, dan
langkah verifikasi manual.

---

## 1. Penyebab yang sudah diperbaiki di repo

### A. Tanda tangan APK berubah setiap build (penyebab utama)
Sebelumnya `android/app/build.gradle` memakai:

```gradle
buildTypes { release { signingConfig signingConfigs.debug } }
```

Runner GitHub Actions selalu bersih, jadi `~/.android/debug.keystore` **dibuat ulang setiap
run** → setiap APK punya sertifikat berbeda. Memasang APK baru di atas aplikasi yang sudah
terpasang akan ditolak Package Manager. Beberapa OEM (MIUI/Realme/Oppo) menampilkan
penolakan ini sebagai **"Ada masalah saat mengurai paket"**, bukan pesan signature.

Perbaikan: release sekarang memakai keystore **stabil** `android/app/edutask-signing.p12`
(dapat ditimpa lewat `android/key.properties` atau secret `ANDROID_KEYSTORE_BASE64`).
Semua build berikutnya bisa menimpa build sebelumnya tanpa uninstall.

### B. Skema tanda tangan & minSdk
Flutter 3.35 **memaksa `flutter.minSdkVersion = 24`** dan menimpa nilai di bawahnya, jadi APK
ini adalah **Android 7.0 (API 24)+**. Karena itu v1 (JAR) signature tidak wajib — Android 7+
memverifikasi lewat **v2/v3**. Build tetap mengaktifkan ketiga skema; validasi CI mewajibkan
v2 dan hanya mewajibkan v1 jika `minSdk < 24`.

### C. `jniLibs.useLegacyPackaging=false` dipaksa pada minSdk 21
AGP menulis `android:extractNativeLibs="false"` yang tidak dikenal di Android 5/6.
Override tersebut dihapus; AGP kembali memilih nilai yang sesuai minSdk.

### D. Distribusi file rawan korup
Artifact GitHub Actions berbentuk **ZIP**; di HP banyak pengguna tidak sengaja memasang
file ZIP / file hasil ekstraksi yang salah. Sekarang setiap build menerbitkan file
**`.apk` mentah** di halaman Release + `SHA256SUMS.txt`.

---

## 2. Cara memasang yang benar

1. Buka **Releases** repo → tag **`latest-apk`**.
2. Pilih satu file:
   - `EduTask-<versi>-arm64-v8a.apk` → hampir semua HP Android modern (paling kecil).
   - `EduTask-<versi>-armeabi-v7a.apk` → HP lama 32-bit.
   - `EduTask-<versi>-universal.apk` → semua ABI dalam satu file (paling besar).
3. Unduh **langsung ke HP** (jangan lewat WhatsApp/kompresi ulang).
4. Buka dari notifikasi/File Manager → izinkan **Install unknown apps**.
5. Jika muncul "aplikasi tidak terpasang"/"paket bentrok": **uninstall EduTask lama dulu**
   (build lama ditandatangani kunci berbeda), lalu pasang lagi.

### Verifikasi checksum (opsional, di HP)
Aplikasi seperti *Hash Droid* / Termux:
```
sha256sum EduTask-1.1.0-arm64-v8a.apk
```
Bandingkan dengan isi `SHA256SUMS.txt` di halaman Release. Jika berbeda → unduhan korup,
unduh ulang.

---

## 3. Jika masih gagal: cocokkan pesan dengan penyebab

| Pesan / gejala | Penyebab | Tindakan |
|---|---|---|
| "Ada masalah saat mengurai paket" saat file dibuka | File bukan APK (ZIP/rusak) | Unduh `.apk` dari Release, cek SHA-256 |
| "App not installed" / "paket bentrok" setelah memilih Install | Signature berbeda dari app yang sudah terpasang | Uninstall app lama, pasang ulang |
| "Aplikasi tidak mendukung perangkat ini" | ABI tidak cocok (mis. memasang arm64 di HP 32-bit) | Pakai `armeabi-v7a` atau `universal` |
| "Your device is not compatible" / "Ada masalah saat mengurai paket" | Android 5–6 (API 21–23) | **Tidak didukung** — aplikasi butuh Android 7.0+ (Flutter 3.35) |
| Berhasil install tapi langsung tertutup | Crash runtime | Kirim `adb logcat -d \| grep -A30 "FATAL EXCEPTION"` |

---

## 4. Bukti validasi di CI (setiap build)

Workflow **Build EduTask APK** menjalankan, untuk setiap APK:

- `unzip -t` → integritas ZIP/APK
- `aapt dump badging` → package `com.edutask.sekolah`, `sdkVersion` (24), `targetSdkVersion`, `native-code`
- `apksigner verify --verbose --print-certs` → memastikan **v1/v2/v3 valid** (build gagal kalau tidak)
- `zipalign -c -v 4` → alignment
- `sha256sum` → checksum yang dipublikasikan

Job **install-test** kemudian:
1. Menjalankan emulator Android API 30 (x86_64)
2. `adb install -r` APK universal
3. `am start -W` → harus `Status: ok`
4. Menunggu 15 detik, memeriksa `FATAL EXCEPTION` di logcat
5. Relaunch lewat `monkey` untuk memastikan cold start kedua juga sehat

---

## 5. Mengganti keystore untuk produksi

Keystore yang di-commit adalah **kunci test** (bukan Play Store). Untuk memakai kunci
pribadi tanpa mengubah kode:

1. Buat keystore lokal:
   ```bash
   keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Base64-kan: `base64 -w0 upload.jks`
3. GitHub → Settings → Secrets → Actions:
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
4. Jalankan ulang workflow. Build akan memakai keystore Anda.

> Setelah mengganti kunci, pengguna **harus uninstall sekali** karena signature berubah.
