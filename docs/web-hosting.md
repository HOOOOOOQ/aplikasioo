# Publikasi Web EduTask (GitHub Pages)

Dokumen ini menjelaskan cara versi **Web** EduTask dibangun dan diterbitkan,
apa yang publik, apa yang tidak, dan cara memperbaikinya bila deploy gagal.

---

## 1. URL

| Lingkungan | URL |
|---|---|
| Produksi (otomatis dari `main`) | <https://hooooooq.github.io/aplikasioo/> |
| Lokal (mode pengembangan) | <http://localhost:8080> — `bash scripts/web/run_web.sh` |
| Pratinjau build rilis | `bash scripts/web/build_web.sh --serve` |

Aplikasi memakai **hash strategy** (`…/#/admin`), jadi refresh dan tombol Back
bekerja tanpa aturan rewrite di server.

## 2. Apa yang dipublikasikan

Yang diunggah **hanya** hasil `flutter build web` (HTML, JS, ikon, manifest).
Tidak ada kunci rahasia di dalamnya:

* `SUPABASE_ANON_KEY` memang dirancang untuk publik — batas keamanan data ada di
  **RLS** Postgres, bukan di penyembunyian kunci.
* `SUPABASE_SERVICE_ROLE_KEY` **tidak pernah** dipakai di Flutter. Workflow
  memeriksa hasil build dan **menggagalkan job** bila string `service_role`
  ditemukan di `build/web`.
* Login tetap wajib; tanpa akun, isi aplikasi tidak dapat dibuka.

Artinya situs ini setara dengan APK yang sudah publik di release `latest-apk`:
shell aplikasi publik, data tidak.

## 3. Cara kerja workflow

`.github/workflows/deploy-web.yml`

1. **Job `build`** — berjalan pada **push ke `main`** dan pada **PR**.
   * `flutter pub get`
   * memastikan secret `SUPABASE_URL` & `SUPABASE_ANON_KEY` terisi (gagal cepat
     dengan pesan jelas bila kosong)
   * `flutter build web --release --base-href=/<repo>/`
   * verifikasi artefak (`index.html`, `main.dart.js`, `manifest.json`,
     `flutter_bootstrap.js`, `404.html`, teks `EduTask`)
   * cek `service_role` tidak ada di bundle
   * pada PR: unggah artifact `web-build-pr` (7 hari) agar bisa diperiksa
   * pada `main`: unggah artefak Pages
2. **Job `deploy`** — hanya pada push ke `main` / `workflow_dispatch`.
   * `actions/configure-pages@v5` dengan `enablement: true` (mencoba
     mengaktifkan Pages otomatis)
   * `actions/deploy-pages@v4`
   * menulis ringkasan + URL ke job summary

Build ulang otomatis setiap ada perubahan pada `lib/**`, `web/**`,
`pubspec.yaml`, `pubspec.lock`, atau workflow ini. Perubahan dokumentasi saja
tidak memicu build.

## 4. Menyiapkan dari nol

1. **Secrets** — Settings → Secrets and variables → Actions:
   * `SUPABASE_URL` — contoh `https://abcdefghijklmnop.supabase.co`
   * `SUPABASE_ANON_KEY` — kunci *anon public* (bukan `service_role`)
2. **Pages** — Settings → Pages:
   * *Source*: **GitHub Actions**
   * Bila `enablement: true` berhasil, langkah ini tidak perlu dilakukan manual.
3. **Jalankan** — Actions → *Deploy Web (GitHub Pages)* → **Run workflow**,
   atau push apa pun yang menyentuh `lib/`.

## 5. Bila deploy gagal

| Gejala | Penyebab | Tindakan |
|---|---|---|
| `Resource not accessible by integration` pada langkah *Setup Pages* | Token CI tidak boleh mengaktifkan Pages | Settings → Pages → Source: **GitHub Actions**, lalu jalankan ulang workflow |
| `Secret SUPABASE_URL dan/atau SUPABASE_ANON_KEY belum diatur` | Secret belum ada / salah nama | Tambahkan di Settings → Secrets and variables → Actions |
| Halaman terbuka tapi layar putih | `base-href` salah (mis. disajikan di sub-path lain) | Pastikan Pages menyajikan dari `/<repo>/`; `--base-href` dihitung otomatis dari nama repo |
| Login gagal padahal APP jalan | Secret menunjuk project Supabase yang berbeda dengan APK | Samakan `SUPABASE_URL` dengan project yang dipakai build APK |
| Halaman 404 dirasa kasar | `web/404.html` dipakai apa adanya | Ubah berkas itu bila perlu; ikut tersalin saat build |

## 6. Deploy ke host lain

Isi `build/web` bersifat statis, jadi bisa dipasang di host apa pun:

* **Netlify / Cloudflare Pages** — salin juga `web/_redirects` (sudah ada di
  `build/web`) bila memakai path strategy.
* **Vercel** — framework *Other*, output `build/web`.
* **Nginx** — `root /var/www/edutask;` + `try_files $uri $uri/ /index.html;`
  (rewrite hanya diperlukan untuk path strategy).
* **Sub-path** — `BASE_HREF=/edutask/ bash scripts/web/build_web.sh`.

Selalu sajikan lewat **HTTPS**; Supabase Auth menolak origin `http://` selain
localhost.

## 7. Batasan yang masih berlaku

* **Migration `007` belum dijalankan** di database mana pun, jadi tombol
  *Sematkan* akan menampilkan pesan error sampai SQL
  [`docs/round6-edutask.md`](round6-edutask.md) §3 dieksekusi. Ekspor CSV/PDF
  tidak terpengaruh.
* Uji manual **pin** dan **ekspor PDF** di browser nyata belum dilakukan;
  statusnya tetap **BELUM TERVERIFIKASI**.
* Halaman Pages memakai kode dari `main`; branch PR tidak diterbitkan.
