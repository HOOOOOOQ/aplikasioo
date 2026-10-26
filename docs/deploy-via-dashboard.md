# Deploy & uji `create-teacher` — 100% lewat browser (tanpa CLI)

Panduan ini untuk yang mengerjakan semuanya dari **Supabase Dashboard** dan **GitHub web**.
Tidak perlu `npm`, tidak perlu `supabase login`.

---

## 0. Samakan dulu: project mana yang dipakai APK?

| Yang dicek | Lokasi |
|---|---|
| URL project yang dipakai APK | GitHub → repo → **Settings → Secrets and variables → Actions → `SUPABASE_URL`** |
| Project tempat function berada | Dashboard Supabase tempat Anda login sekarang |

Kalau nilainya beda project, **tidak ada kode yang bisa menyelamatkan** — token admin akan
selalu ditolak (401). Samakan dulu sebelum lanjut.

Catat juga **Reference ID** di **Project Settings → General** (20 karakter). Dipakai untuk
memastikan Anda melihat project yang benar.

---

## 1. Cek apakah function sudah ada

Dashboard → **Edge Functions**.

- Tidak ada `create-teacher` → klik **Deploy a new function** → pilih **Via Editor** →
  name: `create-teacher` → Create.
- Sudah ada → klik namanya → **Edit** (atau ikon pensil / **Deploy a new version**).

---

## 2. Tempel kode terbaru

1. Buka tab baru:
   `https://raw.githubusercontent.com/HOOOOOOQ/aplikasioo/main/supabase/functions/create-teacher/index.ts`
2. Select all → Copy.
3. Di editor dashboard, **hapus semua isi** lalu paste.
4. Klik **Deploy** (untuk function baru) atau **Deploy updates** (untuk versi baru).
5. Tunggu sampai status **Deployed / ACTIVE** (±10 detik).

Editor dashboard sudah punya Deno, jadi `import { serve } from "https://deno.land/std@..."` dan
`import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0"` langsung jalan.
Pesan kuning soal tipe (`Cannot find name 'Deno'`, dsb.) bisa diabaikan — itu hanya type-check editor.

---

## 3. Aktifkan verifikasi JWT (pengganti `config.toml`)

Deploy lewat dashboard **tidak membaca** `supabase/config.toml`, jadi atur manual:

Edge Functions → `create-teacher` → **Settings** → aktifkan
**Verify JWT with legacy secret** → **Save**.

Untuk `student-access` dan `update-student-task-status` biarkan **OFF** (dipakai siswa tanpa login).

---

## 4. Cek Secrets

Edge Functions → **Secrets** (atau **Manage secrets**).

Di project hosted, tiga secret ini **otomatis tersedia**: `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`. Function versi baru hanya butuh dua yang pertama.

- Sudah ada → **jangan diubah**.
- Belum ada → **Add new secret** lalu isi nilainya dari **Project Settings → API**.
- Pernah diisi manual dengan nilai dari project lain → **hapus/overwrite** dengan nilai project ini.

> `SUPABASE_SERVICE_ROLE_KEY` yang salah tidak lagi muncul sebagai 401. Function akan membalas
> **500 `server_misconfigured`** — itu sinyal jelas bahwa masalahnya di secret, bukan di sesi admin.

---

## 5. Pastikan akun admin valid

Dashboard → **SQL Editor** → New query:

```sql
select p.id, p.email, p.role, p.is_active, u.email as auth_email
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'admin';
```

Harus ada baris dengan `role = 'admin'` dan `is_active = true`, dan `auth_email` = email yang
Anda pakai login.

Perbaiki bila perlu:

```sql
update public.profiles
set role = 'admin', is_active = true
where email = 'admin@sekolah.id';
```

---

## 6. Uji dari browser (tanpa CLI)

Buka file **`docs/tester-create-teacher.html`** di Chrome (double-click dari folder repo, atau
drag ke tab browser). Isi:

1. `SUPABASE_URL`
2. `SUPABASE_ANON_KEY` (anon/publishable, bukan service_role)
3. email + password admin
4. (opsional) email + password guru untuk uji 403

Lalu klik **Jalankan tes aman**. Yang diharapkan:

| Pemeriksaan | Harapan | Arti bila beda |
|---|---|---|
| Request tanpa Authorization | 401 | Kalau 200/500 → JWT verify belum aktif & ada masalah lain |
| Token palsu | 401 | Kalau 200 → verifikasi token tidak berjalan |
| Login admin | 200 | Kalau gagal → email/password/konfirmasi email salah |
| Profil admin | true | Kalau false → perbaiki langkah 5 |

Lalu **Uji non-admin (403)** → harus `403` (bukan 401, bukan 200).
Terakhir **Uji undang guru** → `200`, tetapi ini **benar-benar membuat akun** di database.

Hapus akun uji setelah selesai: Dashboard → **Authentication → Users** → pilih user uji →
**Delete user** (baris `profiles` ikut terhapus via `on delete cascade`).

### Alternatif: DevTools Console

Buka Console di tab mana pun, lalu:

```js
await (await fetch('https://<REF>.supabase.co/functions/v1/create-teacher', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', apikey: '<ANON_KEY>' },
  body: '{}',
})).status; // harapan: 401
```

---

## 7. Cek log function (kalau perilakunya aneh)

Edge Functions → `create-teacher` → **Logs**.

- `create-teacher: verifikasi token gagal: ...` → token admin ditolak (sesi kedaluwarsa / project
  berbeda).
- `create-teacher: service role key tidak cocok...` → secret salah project.
- Tidak ada log sama sekali → request ditolak **gateway** sebelum function jalan (JWT verify
  aktif dan token tidak valid — normal untuk uji tanpa token).

Tidak ada log yang mencetak access token, password, atau service_role key — memang didesain begitu.

---

## 8. Pasang APK terbaru

Perbaikan di sisi aplikasi (refresh token otomatis + pesan error spesifik) hanya ada di build baru.

1. GitHub repo → **Actions** → **Build EduTask APK** (run terbaru di `main`, hijau).
2. Scroll ke bawah → **Artifacts** → `edutask-release-apk` → download → unzip.
3. Install `app-release.apk` (uninstall versi lama bila signature berubah).
4. Pastikan build memakai Secrets `SUPABASE_URL`/`SUPABASE_ANON_KEY` — kalau kosong, APK jadi
   mode demo dan tidak bisa login.

---

## 9. Uji di aplikasi

1. Login admin → **Data Guru** (daftar lama harus tetap tampil).
2. **Undang Guru** → isi data → tombol berubah “Memproses...” → SnackBar sukses.
3. Guru baru muncul di daftar; login sebagai guru itu untuk memastikan bisa masuk `/guru`.
4. Login sebagai guru → coba akses `Data Guru` → aplikasi mengarahkan ke `/login`, dan server
   tetap menolak dengan **403**.

---

## 10. Masih 401? Cocokkan dialog di aplikasi

| Dialog | Arti | Tindakan |
|---|---|---|
| Ditolak Server (401) | Token admin ditolak | Pastikan langkah 0 (project sama) + langkah 3; logout → login ulang |
| Akses Ditolak (403) | Bukan admin aktif | Langkah 5 |
| Edge Function Belum Dideploy (404) | Function tidak ada di project itu | Langkah 1–2 |
| Koneksi Bermasalah | HP/browser tidak bisa reach `*.supabase.co` | Ganti jaringan, cek DNS |
| 500 `server_misconfigured` | Secret salah/berbeda project | Langkah 4, lalu redeploy (langkah 2) |
| Data Tidak Valid (409) | Email sudah dipakai | Pakai email lain / hapus user lama |
| Supabase Belum Dikonfigurasi | APK tanpa `--dart-define` | Set GitHub Secrets, build ulang |
