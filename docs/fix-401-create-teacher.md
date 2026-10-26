# Perbaikan HTTP 401 — Edge Function `create-teacher` (Data Guru)

Dokumen ini merangkum audit, diagnosis, perubahan, dan langkah manual yang masih diperlukan.

## 1. Bukti & diagnosis

Error di aplikasi:

```
FunctionHttpException (status: 401, details: {error: Unauthorized}, reasonPhrase: Unauthorized)
```

Titik penting: **body error berbentuk `{"error": "Unauthorized"}`**. Gateway Supabase
tidak memakai bentuk itu — untuk JWT tidak valid gateway membalas
`{"code":401,"message":"Invalid JWT"}` atau `{"message":"Missing authorization header"}`.
Bentuk `{"error":"Unauthorized"}` persis berasal dari kode function
(`supabase/functions/create-teacher/index.ts`), pada blok verifikasi token.

Kesimpulan diagnosis:

| Hipotesis | Status |
|---|---|
| A. Gateway menolak karena token tidak ada/kedaluwarsa | Mungkin, tetapi body akan berformat `{code,message}` — bukan bukti utama |
| B. Authorization memakai access token admin yang benar | **Tidak selalu** — token bisa kedaluwarsa saat invoke (function tidak memanggil refresh) |
| C. apikey yang dikirim sesuai | Ya, dikirim otomatis oleh `functions_client`; bukan penyebab |
| D. Function sudah dideploy | **Ya** — function sampai mengeksekusi kode dan membalas JSON sendiri |
| E. Konfigurasi `verify_jwt` | Tidak konsisten: repo tidak punya `config.toml`, deployment disarankan `--no-verify-jwt`, sehingga validasi hanya di dalam function |
| F. Function mengembalikan 401 sendiri | **Ya — ini penyebab langsung**: `auth.getUser()` menolak token |
| G. Env server belum dikonfigurasi | Bukan penyebab 401 (itu 500 `server_misconfigured`), tetapi tetap diperketat |

Akar masalah:

1. Client memanggil function **tanpa menjamin access token masih valid**. Jika access token
   kedaluwarsa (aplikasi lama terbuka / resume setelah lama), `getUser()` membalas error dan
   function mengembalikan 401.
2. Function memakai **anon key** (`SUPABASE_ANON_KEY`) untuk membuat client verifikasi. Bila
   secret itu tidak ada / tidak cocok (mis. project memakai publishable key baru), verifikasi
   token gagal. Ini ketergantungan yang tidak perlu.
3. Tidak ada `supabase/config.toml`, sehingga status `verify_jwt` bergantung pada flag deploy
   manual dan mudah tidak konsisten antar-function.
4. Client menelan semua error menjadi satu pesan generik, sehingga 401 (sesi/project), 403
   (bukan admin), 404 (belum deploy), dan 500 (secret) tidak bisa dibedakan.

## 2. Perubahan

### Flutter

- `lib/features/auth/data/auth_repository.dart`
  - `createTeacherAccount` memvalidasi sesi, memanggil `refreshSession()` sebelum invoke,
    menolak token kedaluwarsa, lalu mengirim `Authorization: Bearer <accessToken>` eksplisit.
  - Error dipetakan oleh `TeacherInviteException.fromFunctionError` → kode `session_expired`,
    `unauthorized`, `forbidden`, `not_deployed`, `invalid_input`, `server`, `network`.
  - Tidak ada retry otomatis tanpa batas; tidak ada token/secret yang dicetak.
- `lib/features/admin/presentation/pages/admin_teachers_page.dart`
  - Indikator proses pada FAB (bukan dialog loading yang rawan salah `pop`).
  - Dialog error spesifik per penyebab; tombol **Login Ulang** hanya muncul untuk sesi
    berakhir / 401, lalu `signOut()` + navigasi ke `/login`.
  - Tetap memakai `authRepositoryProvider`; daftar guru dan fitur lain tidak diubah.
- `test/features/auth/teacher_invite_error_test.dart` — unit test pemetaan 401/403/404/409/500/0
  dan memastikan pesan tidak memuat password/secret.

### Edge Function

- `supabase/functions/create-teacher/index.ts`
  - Identitas admin diambil **hanya** dari bearer token, diverifikasi `auth.getUser(token)`
    memakai service_role client (GoTrue memvalidasi signature + expiry).
  - Role dibaca dari `profiles` via service_role (sumber tepercaya, bypass RLS).
  - Tidak lagi bergantung pada `SUPABASE_ANON_KEY`; mendukung fallback `SERVICE_ROLE_KEY`.
  - Validasi email/nama/password, cek duplikasi (409), rollback user bila insert profil gagal,
    respons konsisten `{error, code}` tanpa membocorkan credential.
  - 401 hanya untuk token tidak valid/kedaluwarsa; 403 untuk bukan admin aktif.
  - **Baru:** bila `auth.getUser()` gagal karena `SUPABASE_SERVICE_ROLE_KEY` tidak cocok
    dengan `SUPABASE_URL` (mis. secret project lain), respons menjadi **500
    `server_misconfigured`**, bukan 401 — supaya kesalahan konfigurasi server tidak
    disalahartikan sebagai sesi admin bermasalah.
- `supabase/config.toml` — `create-teacher` `verify_jwt = true`; endpoint siswa `false`.
- `scripts/test-create-teacher.mjs` — uji E2E 401/403/200 tanpa membocorkan token.
- `README.md` — langkah deploy, diagnosis 401, dan troubleshooting diperbarui.

## 3. Langkah manual yang masih diperlukan (pemilik project)

1. Deploy ulang function (wajib, karena kode server berubah):
   ```bash
   supabase link --project-ref <ref>
   supabase functions deploy create-teacher
   ```
2. Pastikan Edge Function **Secrets** berisi `SUPABASE_URL` dan
   `SUPABASE_SERVICE_ROLE_KEY` (nama harus sama; nilai tidak boleh dibagikan).
3. Pastikan project function = project pada `--dart-define=SUPABASE_URL` saat build APK.
4. Pastikan baris admin: `role='admin'`, `is_active=true` di tabel `profiles`.
5. Uji: `node scripts/test-create-teacher.mjs` (lalu `CREATE_TEST_TEACHER=1` untuk jalur 200).
6. Build APK baru agar perbaikan client ikut terbawa.
