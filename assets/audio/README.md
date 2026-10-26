# Aset audio

## `welcome.wav`

- **Dipakai oleh**: `lib/core/services/welcome_sound.dart` (suara pembuka splash).
- **Format**: WAV PCM mono 16-bit, 22.050 Hz, durasi ±1 detik.
- **Isi saat ini**: nada pembuka (chime) tiga nada yang dibuat secara sintetis
  di dalam repositori ini. Ini **bukan** rekaman ucapan "Welcome to EduTask."
  karena belum ada rekaman berlisensi yang tersedia saat rebuild.
- **Lisensi**: dibuat sendiri untuk proyek ini (bebas dipakai di dalam aplikasi).
- **Volume**: diputar pada 0.65 dengan audio context `notificationEvent`
  (Android) sehingga tidak memaksa bunyi pada mode senyap.

## Mengganti dengan rekaman ucapan

1. Siapkan rekaman "Welcome to EduTask." berlisensi (mis. hasil rekaman sendiri
   atau lisensi bebas) berdurasi ≤ 3 detik.
2. Simpan sebagai `assets/audio/welcome.wav` (PCM 16-bit, mono) — jangan ubah
   nama berkas karena dirujuk dari kode.
3. Jalankan `flutter pub get` lalu build ulang. Tidak ada perubahan kode yang
   diperlukan.
4. Uji di perangkat: buka aplikasi dengan "Suara pembuka" aktif, lalu kembali
   dari halaman lain — suara **tidak boleh** diputar ulang.

Catatan: pemutaran audio tidak dapat diverifikasi tanpa perangkat/emulator;
statusnya dicatat sebagai *belum terverifikasi* di laporan ronde 4.
