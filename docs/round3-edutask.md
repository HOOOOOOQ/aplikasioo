# EduTask — Ronde 3: Perbaikan Skema Supabase, Sesi Auth, Database & Bug Terkait

Versi aplikasi: **1.2.0** (versionCode mengikuti nomor run CI, build #70)
Branch: `arena/e59ba061-aplikasioo` → PR **#59**
Tanggal: 2026-10-26

> **Batas kejujuran laporan ini.** Lingkungan kerja tidak memiliki akses ke project
> Supabase (URL/anon key/service role/dashboard) dan tidak memiliki Flutter SDK
> lokal. Karena itu:
>
> - **Terverifikasi**: `flutter analyze`, `flutter test` (121 tes), build APK release,
>   validasi APK (aapt/apksigner), sintaks 5 migration, typecheck 4 Edge Function,
>   sintaks 92 file Dart.
> - **BELUM terverifikasi**: eksekusi migration `005` di project Supabase,
>   `NOTIFY pgrst`, deployment Edge Function, dan seluruh integration test
>   (terbitkan kode, verifikasi kode, klaim ganda, RLS per peran).
>
> Perbaikan backend **belum berlaku** sampai migration & function di-deploy
> (langkah ada di §9).

---

## 1) Apakah tabel `public.kode_akses_siswa` sudah ada sejak awal?

**Tidak dapat dipastikan langsung dari dalam lingkungan ini** — tidak ada akses ke
project Supabase. Yang bisa dipastikan:

- Tabel itu **didefinisikan** di `supabase/migrations/004_access_codes_audit.sql`
  (sudah ada di repo sejak ronde 2).
- Pesan yang dilaporkan — `Could not find the table 'public.kode_akses_siswa' in the
  schema cache` (`PGRST205`) — adalah pesan **PostgREST** ketika tabel tidak ada di
  schema cache **dan** tidak ditemukan di database pada saat reload.
- Tidak ada bukti tabel dinamai lain: seluruh query aplikasi
  (`access_code_repository.dart`) dan Edge Function (`student-codes`,
  `student-access`) memakai nama `kode_akses_siswa` beserta kolom yang sama dengan
  definisi di `004`. Karena itu **tidak dibuat tabel duplikat** dan **tidak ada
  kolom yang diganti nama**.

Kesimpulan kerja: penyebab paling mungkin adalah **migration `004` belum pernah
dijalankan** di project yang dipakai aplikasi (atau dijalankan pada project lain).
Migration `005` dibuat agar aman untuk kedua kondisi: tabel belum ada (dibuat) atau
tabel ada tapi parsial (kolom/FK/policy dilengkapi).

Konfirmasi pasti (butuh dashboard, 1 menit):

```sql
select table_schema, table_name
from information_schema.tables
where table_name = 'kode_akses_siswa';
```

Setelah `005` dijalankan, aplikasi juga bisa memeriksanya sendiri:
**Pengaturan → Periksa skema database** (memanggil `public.edutask_schema_health()`).

---

## 2) Penyebab error "schema cache"

Ada dua lapis masalah yang saling menutupi:

| Lapis | Penyebab | Bukti |
|---|---|---|
| Database | Tabel/fungsi kode akses tidak dikenal API (`PGRST205`, dan `PGRST202` untuk RPC yang belum ada) | Pesan yang dilaporkan pengguna; tidak ada definisi tabel di project |
| Aplikasi | `AppError._fromPostgrest` tidak mengenali `PGRST205`, sehingga pesan mentah PostgREST tampil apa adanya tanpa tindakan | `lib/core/utils/app_error.dart` sebelum perubahan |
| Dashboard | `AkunRepository.fetchDashboardCounts()` memakai satu `Future.wait` berisi 6 query; satu tabel hilang ⇒ **seluruh** dashboard gagal, bukan hanya kartu "Kode akses aktif" | `lib/shared/repositories/akun_repository.dart` sebelum perubahan |

Perbaikan:

- `005` membuat objek yang hilang **dan** mengakhiri file dengan
  `notify pgrst, 'reload schema'` (mekanisme resmi PostgREST, bukan menebak).
- `AppError` memetakan `PGRST205/202/204/42P01/42883` ⇒ kode `schema_not_ready`
  dengan judul **"Skema database belum siap"** dan petunjuk menjalankan migration
  `005` + membuka **Periksa skema**.
- Dashboard menghitung tiap metrik terpisah; metrik yang gagal ditampilkan `—`
  (bukan `0` palsu) dan muncul banner **Periksa skema**.

---

## 3) Migration: perlu? sudah dijalankan?

- **Perlu**: ya, untuk project yang `004`-nya belum pernah dijalankan.
- **Ditambahkan di repo**: `supabase/migrations/005_access_codes_schema_repair.sql`
  (491 baris, idempoten, non-destruktif).
- **Sudah dijalankan di project Supabase?** **BELUM.** Tidak ada akses project dari
  lingkungan ini, jadi tidak mungkin dijalankan atau diklaim berhasil.

Isi `005`:

1. `guru_handles_kelas(uuid)` (`create or replace`).
2. `kode_akses_siswa`: `create table if not exists` + `add column if not exists`
   untuk 14 kolom; FK `kelas_id`/`siswa_id`/`used_by_siswa_id`/`created_by`
   ditambahkan **hanya bila kolomnya belum menjadi bagian FK** (dicek lewat
   `pg_constraint.conkey` + `pg_attribute`, bukan teks constraint).
3. `check (status in (...)) not valid` (baru divalidasi untuk baris baru).
4. Index `kelas_id`, `siswa_id`, `status`, `created_at`; unique index `kode_hash`
   hanya bila belum ada (dengan penanganan `unique_violation` → `raise warning`,
   bukan gagal total).
5. RLS aktif, 2 policy SELECT (admin semua, guru kelas yang diampu),
   `revoke all from anon, authenticated`, `grant select to authenticated`,
   `grant all to service_role` (tidak ada policy tulis untuk client).
6. `kode_akses_attempt`, `audit_log` + `audit_row_change()` + trigger `audit_kode`.
7. `claim_kode_akses(text, uuid)` — `SELECT ... FOR UPDATE`, alasan `not_found`,
   `revoked`, `used`, `expired`, `wrong_student`, `class_mismatch`; hanya
   `service_role` yang boleh `execute`.
8. **Baru:** `kode_akses_stats()` (SECURITY INVOKER ⇒ RLS tetap berlaku,
   total/active/used/expired/revoked) untuk statistik dashboard.
9. **Baru:** `edutask_schema_health()` (hanya admin) — tabel, fungsi, RLS, jumlah
   policy, kolom hilang, `anon_can_select_siswa`, versi `edutask-schema-005`.
10. `notify pgrst, 'reload schema'` + contoh query verifikasi manual.

Validasi: seluruh 5 file migration lolos parser PostgreSQL (`pgsql-parser`) — hanya
membuktikan **sintaks**, bukan semantik runtime.

---

## 4) Penyebab "Sesi tidak valid. Login ulang."

**Direproduksi, bukan dugaan.** `student-codes` membuat client supabase-js dengan
`global.headers.Authorization` lalu memanggil `auth.getUser()` **tanpa argumen**:

```
getUser()      -> {"user":null,"error":{"name":"AuthSessionMissingError","message":"Auth session missing!","status":400}}
getUser(jwt)   -> {"user":"1111…1111","error":null}
```

(uji dengan `@supabase/supabase-js` 2.39.0 + gotrue 2.118.0,
`{persistSession:false, autoRefreshToken:false}`)

Artinya **semua** permintaan terbitkan/cabut kode dijawab **401** — walaupun sesi
admin di aplikasi benar-benar masih berlaku. Pesan 401 lama kemudian menampilkan
"Sesi tidak valid. Login ulang.", yang menyesatkan.

Kontributor kedua: gateway Supabase (`verify_jwt = true` untuk `student-codes`)
menolak token kedaluwarsa **sebelum** function berjalan; responsnya generik
(`code: 401`) sehingga pemetaan lama tidak mengenalinya sebagai masalah sesi dan
tidak mencoba refresh.

Perbaikan:

- Function memakai `verifier.auth.getUser(bearerToken)` (token dari header
  `Authorization` yang dikirim eksplisit oleh aplikasi).
- Kode 401 dibedakan: `missing_token`, `session_expired`, `invalid_token`.
- Aplikasi: `SessionGuard.ensureValidSession()` — token lokal dicek; bila
  kedaluwarsa **atau** server menolak 401, `refreshSession()` resmi GoTrue
  dijalankan **sekali**, lalu permintaan diulang **sekali**.
- Kegagalan jaringan **tidak** dianggap sesi berakhir (`networkError`), token lama
  tetap dipakai bila belum kedaluwarsa (`degraded`).
- 401 (termasuk dari gateway) ⇒ judul **"Sesi login berakhir"** + tindakan
  **Masuk kembali**; bukan lagi "Sesi tidak valid" tanpa jalan keluar.
- Tidak ada token buatan sendiri, tidak ada password tersimpan, JWT tetap
  diverifikasi gateway **dan** GoTrue, role tetap dibaca dari database.

---

## 5) Perbaikan autentikasi & RLS

| Aspek | Status |
|---|---|
| Verifikasi token Edge Function | `getUser(token)` (sebelumnya `getUser()` yang selalu gagal) |
| Refresh token | `refreshSession()` resmi, sekali, dengan retry terbatas |
| Jaringan vs sesi | Dipisahkan (`isNetworkFailure`, `SessionState.networkError`) |
| Sesi habis | Dialog + tombol **Masuk kembali**, profil lama di-invalidate |
| Role | Tetap dari `profiles` di server (`is_admin()`, `is_guru()`, `role`), bukan klaim client |
| RLS `kode_akses_siswa` | Aktif; `anon` **tidak** diberi akses; tidak ada policy tulis untuk client |
| Penulisan kode | Hanya `service_role` (Edge Function); `claim_kode_akses` `execute` hanya `service_role` |
| Statistik | `kode_akses_stats()` SECURITY INVOKER ⇒ guru hanya melihat kelas yang diampu |
| Diagnostik | `edutask_schema_health()` menolak non-admin (`42501`) |
| Kode akses | Dibuat dengan CSPRNG di server, disimpan sebagai hash, plaintext hanya ditampilkan sekali |

Tidak ada perubahan yang melemahkan keamanan: tidak ada bucket publik, tidak ada
`service_role` di Flutter, tidak ada JWT validation yang dimatikan.

---

## 6) File Flutter yang diubah

| File | Perubahan |
|---|---|
| `lib/core/services/session_guard.dart` | **Baru** — `SessionGuard`, `SessionResult`, `SessionState`; refresh resmi, jaringan ≠ sesi mati, `isSessionErrorCode` |
| `lib/core/services/schema_health.dart` | **Baru** — model + pemanggil `edutask_schema_health()` |
| `lib/core/utils/app_error.dart` | `schema_not_ready`; 401 sesi (termasuk gateway); kode domain kode akses (`kode_not_found`, `used`, `revoked`, `expired`, `wrong_student`, `class_mismatch`, `student_token_*`, …); fallback tanpa "Gagal menyimpan data" dan tanpa membocorkan SQL |
| `lib/core/widgets/app_states.dart` | `AppErrorState` dapat aksi sekunder (`actionLabel`/`onAction`) |
| `lib/features/access_codes/data/access_code_repository.dart` | Bearer token eksplisit, retry sekali setelah refresh, tolak status ≥ 400, `fetchStats()` via RPC, error `fetchCodes` tidak ditelan |
| `lib/features/access_codes/domain/access_code.dart` | `AccessCodeStats` (`fromJson`, `fromList` + penanda `approximate`) |
| `lib/features/access_codes/presentation/access_codes_page.dart` | Statistik dari database; banner statistik sementara; sesi berakhir → dialog + login; cegah klik ganda; error `schema_not_ready` punya tombol ke Pengaturan |
| `lib/features/admin/presentation/pages/admin_dashboard_page.dart` | Metrik dihitung terpisah (`—` bila gagal), banner masalah + **Periksa skema**, tombol **Masuk kembali** |
| `lib/features/admin/presentation/widgets/schema_health_dialog.dart` | **Baru** — dialog diagnostik skema |
| `lib/features/admin/presentation/pages/admin_settings_page.dart` | Tombol **Periksa skema database** di bagian "Status server" |
| `lib/shared/repositories/akun_repository.dart` | `DashboardCounts` (nilai + masalah per metrik); error sesi/jaringan tetap diteruskan |
| `lib/features/student/presentation/pages/student_task_detail_page.dart` | Membedakan token identitas siswa (`student_token_*`) dari sesi login |
| `pubspec.yaml`, `lib/core/config/app_info.dart` | Versi 1.2.0 |

### Edge Function

| File | Perubahan |
|---|---|
| `supabase/functions/student-codes/index.ts` | Verifikasi token benar, `schema_not_ready` (503), `server_misconfigured`, audit yang gagal tercatat di log |
| `supabase/functions/student-access/index.ts` | Helper yang sama; rate-limit & lookup membedakan tabel belum ada vs error server; `kode_not_found` |
| `supabase/functions/update-student-task-status/index.ts` | Kode `student_token_missing/invalid/expired` |

### Tes

| File | Isi |
|---|---|
| `test/core/app_error_mapping_test.dart` | +15 tes: PGRST205/202/42P01, 503, 401 gateway & sesi, `kode_not_found`, `used`, `revoked`, `expired`, `server_misconfigured`, fallback tanpa SQL |
| `test/core/session_guard_test.dart` | **Baru** — 10 tes: klasifikasi sesi, jaringan vs kredensial, `SessionResult`, tanpa konfigurasi |
| `test/core/dashboard_health_test.dart` | **Baru** — 8 tes: `DashboardCounts`, `SchemaHealth.fromJson` |
| `test/core/access_code_test.dart` | +3 tes: `AccessCodeStats` |

---

## 7) SQL migration yang ditambahkan

Hanya **satu** file: `supabase/migrations/005_access_codes_schema_repair.sql`.
Tidak ada tabel baru selain yang sudah didefinisikan di `004`
(`kode_akses_siswa`, `kode_akses_attempt`, `audit_log` — semuanya
`create table if not exists`), tidak ada `drop table`, tidak ada `delete`, dan
tidak ada perubahan pada `001`–`004` (yang mungkin sudah dijalankan di project).

---

## 8) Hasil tes & build (dijalankan CI)

| Tahap | Hasil |
|---|---|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | ✅ lolos (run `40353745740`) |
| `flutter test` | ✅ **121 tes** lolos (85 tes lama + 36 tes baru/berubah) |
| `flutter build apk --release` (+ split-per-abi) | ✅ build #70 (`40353745762`) |
| Validasi APK (`aapt`, `apksigner`) | ✅ `com.edutask.sekolah`, versionName `1.2.0`, `sdkVersion 24`, `targetSdkVersion 36`, v2 + v3 |
| Uji instalasi emulator | ⚠️ job "success" tetapi **emulator gagal boot** dan log smoke test tidak dihasilkan — **bukan** bukti runtime |
| Sintaks SQL 001–005 | ✅ `pgsql-parser` |
| Typecheck Edge Functions | ✅ `tsc` strict + shim Deno/supabase-js |
| Sintaks Dart (92 file) | ✅ tree-sitter-dart, 0 error |

### APK (build #70, PR artifact)

| File | Ukuran | SHA-256 |
|---|---|---|
| `EduTask-1.2.0-arm64-v8a.apk` | 26 MB | `e5448b08f337f9028dae208f14f2c4f0a431171e4004e00a383e3e27b5970bc4` |
| `EduTask-1.2.0-armeabi-v7a.apk` | 23 MB | `f002d3a6145cd88437dac910d4cc7beba7c2fced961ea39492d84c65b992f515` |
| `EduTask-1.2.0-universal.apk` | 63 MB | `84a93cfa43a5418e5140ef29f1b80951f7726687968993e526455521b38d4d2a` |
| `EduTask-1.2.0-x86_64.apk` | 27 MB | `f98285d300ab6a37334c5668d921d36e93d0750e1e2041fbcf23890ff6dcd1b8` |

- versionCode: 2070 (arm64), 1070 (armeabi-v7a), 70 (universal), 4070 (x86_64)
- Signer: `C=ID, O=EduTask Sekolah, CN=EduTask`, RSA 2048, **v2 + v3**
- Sertifikat SHA-256: `f3d985e457b01512b34091c25826869ed48fe9efd42b988375fc401562ffcbf9`
  (sama dengan rilis 1.1.0 ⇒ update APK tidak memaksa uninstall)
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`, universal
- Aplikasi rilis `latest-apk` baru diperbarui setelah PR di-merge ke `main`.

---

## 9) Langkah manual yang tersisa (Supabase Dashboard)

1. **Deploy Edge Functions** — Actions → *Deploy Supabase Edge Functions* →
   pilih `student-codes`, `student-access`, `update-student-task-status`
   (butuh secret `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`).
2. **Jalankan migration** — SQL Editor → tempel seluruh isi
   `supabase/migrations/005_access_codes_schema_repair.sql` → Run.
   Ulangi `003_storage_attachments.sql` bila bucket `lampiran-tugas` belum ada.
3. **Verifikasi** (SQL Editor):
   ```sql
   select public.edutask_schema_health();
   select public.kode_akses_stats();
   ```
   `version` harus `edutask-schema-005`, `missing_columns` kosong.
4. **Verifikasi dari aplikasi** — login admin → Pengaturan →
   **Periksa skema database** → harus "Skema lengkap".
5. **Uji terbitkan kode** — Pilih kelas & siswa → **Buat kode** → salin kode.
6. **Uji verifikasi siswa** — Halaman **Identitas** → masukkan kode → nama harus
   muncul; coba kode yang sama lagi (single-use) ⇒ **"Kode sudah dipakai"**.
7. Pastikan `notify pgrst, 'reload schema'` berjalan (sudah ada di akhir `005`).
   Bila PostgREST masih basi, tunggu ±10 detik atau reload schema lewat
   Dashboard → API Settings.

---

## 10) Bug lain yang ditemukan

1. **Dashboard admin "all-or-nothing"** — satu query gagal membuat seluruh
   halaman error. Kini per-metrik, dengan penanda jujur `—`.
2. **404 disalahartikan** — `student-access` mengembalikan 404 untuk kode yang
   salah ketik; `AppError` lama menampilkannya sebagai
   *"Edge Function belum dideploy"*. Kini kode `kode_not_found` ⇒
   **"Kode tidak ditemukan"**.
3. **409/403 kode akses generik** — "Sudah digunakan"/"Akses ditolak" tanpa
   konteks. Kini "Kode sudah dipakai"/"Kode sudah dicabut" + saran minta kode baru.
4. **Token identitas siswa tercampur sesi login** — 401 dari
   `update-student-task-status` bisa memunculkan saran login admin. Kini kode
   `student_token_*` ⇒ "Sesi identitas berakhir, verifikasi ulang kode".
5. **Celah retry** — 401 dari gateway (`verify_jwt`) tidak pernah memicu refresh
   karena tidak punya `code` domain. Kini semua 401 memicu satu kali refresh.
6. **Risiko "sukses palsu"** — bila SDK tidak melempar exception untuk status
   ≥ 400, aplikasi bisa menganggap entri berhasil. Kini status ≥ 400 selalu gagal.
7. **Klik ganda** pada tombol "Buat kode" dapat menerbitkan dua kode. Ditambahkan
   guard `_submitting`.
8. **Statistik dari 200 baris pertama** — angka dashboard kode akses dihitung dari
   daftar yang dimuat (limit 200). Kini memakai RPC `kode_akses_stats()`; bila RPC
   belum ada, UI memakai hitungan cadangan **dan menandainya**.

### Masalah yang belum diselesaikan (jujur)

1. **Migration `005` belum dijalankan** dan Edge Function belum di-deploy — sampai
   itu, tiga bug yang dilaporkan **belum benar-benar hilang di project nyata**.
2. **Integration test belum dijalankan**: buat kode (admin), siswa ditolak membuat
   kode, kode valid/kedaluwarsa/dicabut/single-use, klaim bersamaan (race), sesi
   valid/kedaluwarsa, RLS admin/guru/siswa/anon. Tidak ada project/akun uji.
3. **Roster anon masih membaca `siswa`** (kolom `id, nomor_induk, nama, kelas_id,
   status_aktif, …`) karena alur "pilih nama siswa" berjalan tanpa login. Ini
   **tidak** membuka kode akses, tetapi memuat NIS. Rencana memperketat (Edge
   Function roster + cabut grant `nomor_induk`) belum dikerjakan karena tidak bisa
   diverifikasi tanpa project — dan bila dijalankan sebelum APK baru terpasang,
   alur identitas siswa akan rusak.
4. **Uji instalasi nyata & emulator** tidak berhasil (emulator gagal boot). APK
   divalidasi struktural (aapt/apksigner), bukan dijalankan di perangkat.
5. **Waktu build #70** belum dipublikasikan ke release `latest-apk` (menunggu merge).
