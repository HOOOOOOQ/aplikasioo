# Round 4 — EDUTASK ULTIMATE REBUILD (FIX ALL BUGS & ADD 20+ FEATURES)

Dokumen ini adalah laporan resmi ronde 4. Isinya hanya hal yang **sudah
dikerjakan di kode** dan **hasil verifikasi yang benar-benar dijalankan**.
Hal yang belum bisa diverifikasi (tanpa akses Supabase/perangkat) ditandai
secara eksplisit dan **tidak** diklaim berhasil.

- Branch kerja: `arena/f89eeb41-aplikasioo`
- PR: **#61** → merge commit `024ff0d` (main)
- Baseline sebelum ronde 4: `06cbd53` (v1.2.0, build #72)
- Tanggal: 27 Oktober 2026

---

## 1. Bug yang ditemukan dan diperbaiki

| # | Bug | Bukti | Perbaikan | File |
|---|-----|-------|-----------|------|
| 1 | Tombol Back di beranda langsung menutup aplikasi | Tidak ada `PopScope`/`WillPopScope` di seluruh `lib/` (grep 0 hasil) | `AppBackGuard` + `resolveBackAction` dengan konfirmasi di akar | `lib/core/navigation/back_guard.dart`, `lib/core/routing/app_router.dart` |
| 2 | Back di sub-halaman shell (mis. `/admin/tugas/:id`) tidak konsisten | Shell admin/guru tidak punya penanganan Back sama sekali | Guard dipasang di `ShellRoute` dengan daftar `tabRoutes` | `app_router.dart` |
| 3 | Tab Identitas siswa memakai `push` sementara tab lain `go` | `student_main_page.dart` baris tab 3 | Diseragamkan menjadi `go` | `student_main_page.dart` |
| 4 | Kode akses bisa terbit ganda saat tombol ditekan dua kali / retry | Tidak ada idempotensi di `issue`; dua permintaan = dua baris | `idempotency_key` (uuid) + unique partial index + pra-cek + jalur 23505 | `006_round4_academic_chat.sql`, `student-codes/index.ts`, `access_code_repository.dart` |
| 5 | Kode akses hilang bila refresh daftar gagal setelah terbit | `_openIssueSheet` memanggil `_refresh()` **sebelum** dialog kode; error refresh menggagalkan seluruh alur | Kode ditampilkan di sheet yang sama sebelum refresh; refresh dibungkus try/catch | `access_codes_page.dart` |
| 6 | Sheet penerbitan tertutup otomatis sebelum kode sempat dibaca | `Navigator.pop(context, issued)` di `_submit` | Tidak ada navigasi otomatis; pengguna menutup manual (konfirmasi bila belum disalin) | `access_codes_page.dart` |
| 7 | Splash memakai ikon generik, bukan logo aplikasi | `Icon(Icons.school_rounded)` | `EduTaskLogo` (aset nyata) | `splash_page.dart` |
| 8 | Versi aplikasi di-hardcode (`1.2.0`) tanpa nomor build | `AppInfo.version` konstanta | `package_info_plus` → `AppVersionLabel` (fallback ke konstanta) | `core/services/app_version.dart` |
| 9 | Tidak ada jalan bagi siswa untuk membuka pengaturan/suara pembuka | Tidak ada rute pengaturan siswa | Rute `/siswa/pengaturan` + entri menu & pintasan | `student_settings_page.dart`, `app_router.dart` |
| 10 | Tentang aplikasi hanya bisa dibuka lewat menu tiga titik pada beberapa halaman | PopupMenu guru/siswa | Tombol info eksplisit di AppBar + entri menu + drawer | `admin_shell.dart`, `teacher_shell.dart`, `student_main_page.dart` |
| 11 | Onboarding tidak mengikuti urutan yang diminta (tidak ada langkah login admin/guru, langkah akhir tidak menyebut notifikasi/chat/pengumpulan) | `_steps` lama | 5 langkah ditulis ulang sesuai urutan | `onboarding_page.dart` |

## 2. Akar masalah (root cause)

1. **Back navigation**: aplikasi hanya mengandalkan perilaku default Flutter.
   Tanpa `PopScope`, tombol Back langsung menutup activity saat tidak ada route
   di atasnya; tidak ada satu pun tempat yang tahu "tab mana yang harus
   dituju".
2. **Kode akses ganda**: operasi terbit kode adalah `INSERT` tanpa kunci
   idempotensi. Retry (atau double tap) dianggap permintaan baru.
3. **Kode hilang**: alur UI melakukan navigasi + reload data **sebelum**
   menampilkan hasil yang tidak dapat dipulihkan (plaintext hanya ada di
   respons).
4. **Chat/akademik tidak ada**: belum ada tabel, RPC, maupun halaman. Tidak ada
   bug lama yang bisa "diperbaiki" karena fitur belum ada.
5. **Splash/versi**: nilai versi disalin manual, sehingga berbeda dengan APK
   yang diinstal (build number naik tiap build CI).

## 3. File yang diubah/ditambah

### Baru
```
lib/core/navigation/back_guard.dart
lib/core/services/app_preferences.dart
lib/core/services/app_version.dart
lib/core/services/welcome_sound.dart
lib/core/widgets/app_preferences_section.dart
lib/features/akademik/domain/akademik_models.dart
lib/features/akademik/data/akademik_repository.dart
lib/features/akademik/data/akademik_providers.dart
lib/features/akademik/data/student_akademik_gateway.dart
lib/features/akademik/presentation/{akademik_widgets,pengumuman_page,kalender_page,
  chat_threads_page,chat_room_page,notifikasi_page,pencarian_page,pengumpulan_section}.dart
lib/features/student/presentation/pages/student_settings_page.dart
assets/audio/welcome.wav + assets/audio/README.md
supabase/migrations/006_round4_academic_chat.sql
supabase/functions/student-portal/index.ts
supabase/functions/student-chat/index.ts
test/core/back_guard_test.dart
test/core/akademik_models_test.dart
```

### Diubah
```
lib/core/routing/app_router.dart              (guard + 15 rute baru)
lib/core/widgets/splash_page.dart             (logo, reduce-motion, versi, suara)
lib/features/about/presentation/about_page.dart
lib/features/access_codes/data/access_code_repository.dart
lib/features/access_codes/presentation/access_codes_page.dart
lib/features/admin/presentation/pages/{admin_shell,admin_dashboard_page,admin_settings_page}.dart
lib/features/teacher/presentation/pages/{teacher_shell,teacher_profile_page}.dart
lib/features/student/presentation/pages/{student_main_page,student_task_detail_page}.dart
lib/features/onboarding/presentation/onboarding_page.dart
test/features/onboarding_test.dart
pubspec.yaml  (audioplayers, package_info_plus, assets/audio/)
supabase/config.toml (verify_jwt=false untuk student-portal & student-chat)
supabase/functions/student-codes/index.ts
.github/workflows/deploy-functions.yml
```

## 4. Migrasi database

`supabase/migrations/006_round4_academic_chat.sql` — **belum dijalankan** ke
project Supabase mana pun dari sisi agen (tidak ada akses).

| Objek | Keterangan |
|-------|-----------|
| `alter table kode_akses_siswa add column if not exists idempotency_key` + `uq_kode_akses_idempotency` | mencegah kode ganda |
| `kode_akses_riwayat(int)` | riwayat terbit/cabut/klaim (security invoker) |
| `pengumuman` | judul, isi, target (semua/guru/siswa), kelas opsional, publish |
| `kalender_akademik` | libur/ujian/kegiatan/rapat/lainnya + rentang tanggal |
| `tugas_pengumpulan` | revisi 1–20, jawaban ≤8000, lampiran, status, nilai 0–100, umpan balik |
| `tugas_komentar` | diskusi tugas, validasi penulis per peran |
| `chat_threads` / `chat_members` / `chat_messages` | direct/kelas/tugas, unread via `last_read_at`, `client_id` unik |
| `notifikasi` | profile_id atau siswa_id, tipe, read-state |
| `chat_unread_counts()`, `edutask_search(text,int)`, `akademik_stats()` | RPC baca (security invoker; RLS tetap aktif) |
| `edutask_schema_health()` v006 | menambahkan tabel/kolom baru ke pemeriksaan |
| Trigger `touch_chat_thread` | `last_message_at` & notifikasi chat |

Sifat: idempotent (`if not exists`), non-destruktif, diakhiri
`notify pgrst, 'reload schema'`. Tidak ada `DROP TABLE`/`DROP COLUMN`.

## 5. Perubahan RLS / hak akses

- RLS **aktif** pada semua tabel baru.
- `anon`: hanya `select` pada `pengumuman` (terbit + jadwal tayang) dan
  `kalender_akademik`. **Tidak ada** akses anon ke chat, pengumpulan, komentar,
  atau notifikasi.
- `authenticated`: guru hanya kelas yang diampu (`guru_handles_kelas` /
  `guru_handles_tugas`), admin penuh, siswa **tidak** memakai PostgREST untuk
  data privat.
- Siswa memakai Edge Function bertoken HMAC (`student-portal`, `student-chat`);
  `siswa_id` **hanya** diambil dari token yang diverifikasi server.
- Chat `direct` tidak otomatis terbuka untuk admin (`can_access_thread`).
- Tidak ada `service_role` di aplikasi Flutter; tidak ada bucket yang dibuat
  publik.

## 6. Fitur yang benar-benar selesai (kode + UI + states)

1. **Back guard** — detail/form/dialog/sheet/tab/akar sesuai kebijakan tunggal.
2. **Kode akses idempoten** — tombol nonaktif saat proses, kode tampil di sheet,
   cek status setelah timeout, konfirmasi sebelum menutup.
3. **Pengumuman** (siswa & staff) — daftar, detail, tulis (admin/guru), RLS.
4. **Kalender akademik** — daftar per bulan, filter tipe, tambah (admin).
5. **Pengumpulan tugas** — kirim jawaban, riwayat revisi, status, nilai & umpan
   balik guru.
6. **Penilaian guru** — daftar jawaban siswa + dialog nilai/umpan balik.
7. **Diskusi tugas** — komentar siswa (token) dan guru/admin (RLS).
8. **Chat** — daftar thread + badge unread; ruang chat realtime untuk staff,
   polling untuk siswa; kirim pesan optimistis + retry; pagination "muat lama".
9. **Pusat notifikasi** — daftar, tandai satu/semua dibaca, navigasi ke sumber.
10. **Pencarian global** — RPC untuk staff; pencarian publik untuk siswa.
11. **Statistik akademik** di dashboard admin (pengumpulan, menunggu nilai,
    rata-rata nilai, pengumuman).
12. **Pengaturan** (admin/guru/siswa) — suara pembuka, putar ulang tutorial,
    tautan Tentang; lepas identitas (siswa).
13. **Splash** — logo, gradien biru/putih, animasi masuk, reduce-motion,
    progres berbasis pekerjaan nyata, error + retry, versi+build nyata.
14. **Suara pembuka** — aset lokal, sekali per peluncuran, mengikuti preferensi,
    audio context yang tidak memaksa mode senyap, dispose player.
15. **Onboarding 5 langkah** — Lewati, progres, Berikutnya/Kembali, tersimpan
    lokal, bisa diputar ulang dari Pengaturan.

## 7. Fitur yang butuh konfigurasi/deploy tambahan

| Fitur | Yang harus dilakukan |
|-------|----------------------|
| Semua fitur akademik/chat | Jalankan migration `006` di Supabase SQL Editor |
| `student-portal`, `student-chat` | Deploy Edge Function (workflow `deploy-functions.yml` → pilih function) + set secret `STUDENT_TOKEN_SECRET` (atau pakai service role default) |
| `student-codes` idempotensi | Deploy ulang function setelah migration 006 |
| Suara pembuka | Aset yang ada adalah **chime sintetis**, bukan rekaman ucapan; ganti `assets/audio/welcome.wav` bila ingin ucapan "Welcome to EduTask." |
| Statistik akademik | Tampil setelah migration 006 (RPC `akademik_stats`) |

## 8. Hasil `flutter analyze`

- PR #61, commit `b7d8712`: **0 error** (`flutter analyze --no-fatal-infos
  --no-fatal-warnings`), hanya info/warning lama.
- Rincian lengkap ada di komentar otomatis PR #61.

## 9. Hasil unit & widget test

- PR #61: **140 tests passed** (sebelumnya 121).
- Tes baru: `test/core/back_guard_test.dart` (9 kasus: pop, tab induk, akar +
  konfirmasi, latch double-tap, sub-halaman, push/pop) dan
  `test/core/akademik_models_test.dart` (parsing pengumuman/kalender/chat/
  pengumpulan/statistik/pencarian, termasuk data cacat).
- Tes lama disesuaikan hanya pada judul langkah onboarding yang memang diubah.

## 10. Hasil build

Build APK dijalankan CI (Flutter 3.35.4, JDK 17, `com.edutask.sekolah`,
minSdk 24, target 36). Lihat tabel APK di bagian 11.

## 11. APK (build CI terakhir)

<!-- APK_TABLE -->

## 12. Langkah manual di Supabase & risiko residual

### Langkah manual
1. Jalankan `supabase/migrations/006_round4_academic_chat.sql` (idempotent).
2. Deploy `student-codes`, `student-portal`, `student-chat`.
3. Pastikan Edge Function secret `STUDENT_TOKEN_SECRET` sama dengan yang dipakai
   `student-access` (bila tidak diset, fungsi memakai service role key).
4. Buka aplikasi → Pengaturan → "Periksa skema database" untuk memastikan v006
   terdeteksi.
5. Buat satu kode akses, verifikasi di perangkat siswa, kirim satu chat, unggah
   satu jawaban, lalu nilai dari akun guru.

### Risiko residual (belum terverifikasi)
- Migration 006, RPC, dan RLS belum pernah dieksekusi ke database nyata.
- Chat realtime (Supabase Realtime publication) belum diuji di perangkat.
- Pemutaran audio belum diuji di perangkat; mode senyap belum diverifikasi.
- `package_info_plus`/`audioplayers` baru ditambahkan; `pub get` di CI lolos,
  tetapi perilaku runtime di perangkat belum diuji.
- Mode gelap belum tersedia (preferensi tema belum diekspos agar tidak menjadi
  kontrol palsu).
- Lampiran jawaban siswa (`lampiran_path`) belum punya UI unggah; kolom & RLS
  sudah disiapkan.
- Notifikasi push lokal untuk chat belum diimplementasikan (pusat notifikasi
  in-app sudah ada).
