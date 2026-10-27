# Ronde 6 — Ekspor PDF Laporan & Pin Tugas

Laporan kerja ronde 6 untuk **EduTask** (`HOOOOOOQ/aplikasioo`), dikerjakan di
branch `arena/860055b9-aplikasioo` (branch sesi) tanpa menyentuh `main`.

Status setiap klaim dipisahkan:

| Status | Arti |
|---|---|
| **SELESAI (kode)** | Perubahan ada di repo dan lolos pemeriksaan sintaks lokal. |
| **TERVERIFIKASI CI** | Ditandai hanya setelah `flutter analyze` / `flutter test` / build di GitHub Actions berhasil. |
| **BELUM TERVERIFIKASI** | Butuh perangkat Android, browser, atau project Supabase live. |

> Lingkungan kerja ronde ini **tidak memiliki** Flutter/Dart SDK, JDK, Android
> SDK, `adb`, maupun akses ke project Supabase. Karena itu:
> * validasi lokal = parser Dart (tree-sitter) + parser SQL,
> * validasi runtime = CI (analyze/test/web/APK) + pengujian manual pengguna,
> * **migration 007 belum pernah dijalankan di database mana pun.**

---

## 1. Ringkasan

Dua fitur:

1. **Ekspor PDF** laporan penyelesaian tugas di halaman Laporan admin, memakai
   **sumber data, filter, dan rentang tanggal yang sama** dengan ekspor CSV
   yang sudah ada — karena keduanya sekarang diturunkan dari satu objek
   `ReportDocument`.
2. **Pin tugas**: admin/guru dapat menyematkan tugas agar tampil paling atas,
   dengan urutan deterministik dan otorisasi yang diperiksa di server
   (RLS + RPC), bukan hanya menyembunyikan tombol.

Batas lingkup yang dipatuhi: tidak ada migrasi massal `AppColors.*`, tidak ada
perombakan autentikasi, tidak ada penghapusan fitur/data, dan tidak ada
perubahan `applicationId`/signing key.

---

## 2. Struktur perubahan

### 2.1 Berkas baru

| Berkas | Isi |
|---|---|
| `supabase/migrations/007_tugas_pin.sql` | Kolom `is_pinned`/`position`, index, constraint, RPC `set_tugas_pin`. |
| `lib/shared/models/tugas_sort.dart` | `TugasSorting` — satu-satunya aturan urutan daftar tugas. |
| `lib/shared/models/tugas_pin_policy.dart` | `TugasPinPolicy` — penyaring tampilan tombol pin (bukan kontrol keamanan). |
| `lib/features/reports/domain/report_document.dart` | `ReportFilter`, `ReportRowData`, `ReportDocument` — sumber data tunggal CSV & PDF. |
| `lib/features/reports/services/report_pdf_builder.dart` | Pembentuk dokumen PDF (paket `pdf`, murni Dart). |
| `lib/features/reports/services/pdf_exporter.dart` | Fasad ekspor PDF + hasil terstruktur. |
| `lib/features/reports/services/pdf_export_native.dart` | Android/iOS: `Printing.layoutPdf` / `Printing.sharePdf`. |
| `lib/features/reports/services/pdf_export_web.dart` | Web: unduhan berkas asli (Blob + `<a download>`), tanpa CDN. |
| `lib/features/reports/services/pdf_export_stub.dart` | Fallback platform tak dikenal (gagal dengan pesan jelas). |
| `test/core/tugas_sort_test.dart` | Uji urutan pin. |
| `test/core/tugas_pin_policy_test.dart` | Uji izin pin per peran. |
| `test/core/tugas_pin_model_test.dart` | Uji kompatibilitas payload lama. |
| `test/features/reports/report_document_test.dart` | Uji data laporan (filter, kosong, batas baris, nama berkas). |
| `test/features/reports/report_pdf_builder_test.dart` | Uji pembentukan PDF & jumlah halaman. |

### 2.2 Berkas yang diubah

| Berkas | Perubahan |
|---|---|
| `pubspec.yaml` | `pdf ^3.11.3`, `printing ^5.14.3`, `web ^1.0.0` (versi dikunci agar kompatibel Flutter 3.35). |
| `lib/shared/models/tugas.dart` | Field `isPinned`, `position`, pembacaan aman dari JSON, `copyWith`, `props`. `toJson()` **tidak** mengirim pin. |
| `lib/shared/repositories/tugas_repository.dart` | Filter `tenggatFrom/tenggatTo`, `limit` di server, urutan `TugasSorting`, `fetchReport(...)` menerima filter lengkap, RPC `setPin`. |
| `lib/features/admin/presentation/pages/admin_reports_page.dart` | Filter periode, tombol **Ekspor PDF** di samping CSV, satu `ReportDocument` untuk keduanya. |
| `lib/features/admin/presentation/pages/admin_tasks_page.dart` | Indikator pin, menu Sematkan/Lepas, statistik "Disematkan". |
| `lib/features/teacher/presentation/pages/teacher_tasks_page.dart` | Sama untuk guru pemilik tugas. |
| `lib/features/student/presentation/pages/student_task_list_page.dart` | Lencana baca-saja "Disematkan" (tanpa aksi). |

---

## 3. Migration 007 — SQL lengkap

**Belum dijalankan di database mana pun.** Jalankan manual melalui Supabase
Dashboard → SQL Editor (atau `supabase db push`), setelah meninjau isinya.

Sifat migration:

* **Idempoten** — `add column if not exists`, `drop constraint if exists` +
  `create`, `create index if not exists`, `create or replace function`.
* **Non-destruktif** — tidak menghapus/mengubah baris lama. Semua tugas lama
  otomatis `is_pinned = false, position = 0`.
* **RLS tetap aktif**, tidak ada policy baru yang memperluas akses.
* `security invoker` pada RPC → RLS tetap berlaku; otorisasi diperiksa ulang
  di dalam fungsi.
* `pg_advisory_xact_lock` hanya saat posisi otomatis → dua penulis bersamaan
  tidak mendapat `position` yang sama.
* Tidak memakai `service_role` dan tidak mengubah data siswa/laporan.

```sql
-- ======================================================
-- 007_tugas_pin.sql
--
-- TUJUAN
--   Menambahkan kemampuan **pin tugas** (prioritas tampil di atas) plus
--   urutan manual di antara tugas yang di-pin.
--
--   * `tugas.is_pinned`  boolean NOT NULL DEFAULT false
--   * `tugas.position`   integer NOT NULL DEFAULT 0  (kecil = lebih atas)
--
-- SIFAT
--   * Idempoten: aman dijalankan berulang (add column if not exists,
--     drop constraint if exists + create, create index if not exists,
--     create or replace function).
--   * Non-destruktif: TIDAK menghapus/mengubah data lama. Semua baris lama
--     otomatis bernilai `is_pinned = false, position = 0`, sehingga urutan
--     daftar tugas tetap sama seperti sebelum migration (urut tenggat).
--   * RLS tidak dilemahkan. Tidak ada policy baru yang memperluas akses:
--     penulisan pin memakai policy `tugas` yang sudah ada
--     ("Admin manage tugas" & "Guru manage own tugas") ditambah pemeriksaan
--     ulang di dalam RPC `set_tugas_pin`.
--   * Tidak memakai service_role.
--
-- OTORISASI (server-side, bukan sekadar UI)
--   * RLS `tugas` hanya mengizinkan UPDATE bagi admin atau guru pemilik baris.
--   * RPC `set_tugas_pin` berjalan dengan hak pemanggil (SECURITY INVOKER)
--     sehingga RLS tetap berlaku, lalu memeriksa ulang:
--       - wajib login (auth.uid() tidak null),
--       - admin ATAU guru pemilik tugas (`guru_id = auth.uid()`).
--   * Siswa/anon tidak punya policy UPDATE pada `tugas`, jadi permintaan
--     mereka ditolak (0 baris / 42501) meskipun UI-nya dimanipulasi.
-- ======================================================

-- ------------------------------------------------------
-- 1) Kolom pin & urutan (idempoten, aman untuk data lama)
-- ------------------------------------------------------
alter table public.tugas
  add column if not exists is_pinned boolean not null default false;

alter table public.tugas
  add column if not exists "position" integer not null default 0;

-- Pastikan tidak ada NULL pada data lama (kolom mungkin sudah ada dari
-- percobaan sebelumnya dengan definisi yang berbeda).
update public.tugas set is_pinned = false where is_pinned is null;
update public.tugas set "position" = 0 where "position" is null;

alter table public.tugas alter column is_pinned set not null;
alter table public.tugas alter column is_pinned set default false;
alter table public.tugas alter column "position" set not null;
alter table public.tugas alter column "position" set default 0;

-- Batas wajar posisi: mencegah nilai ekstrem dari klien lama / bug.
-- `not valid` membuat penambahan constraint tidak memindai ulang seluruh tabel
-- besar (data lama sudah pasti memenuhi karena default 0).
alter table public.tugas drop constraint if exists check_tugas_position;
alter table public.tugas
  add constraint check_tugas_position check ("position" >= 0 and "position" <= 1000000) not valid;

-- ------------------------------------------------------
-- 2) Index urutan (mendukung ORDER BY pin, position, tenggat)
-- ------------------------------------------------------
create index if not exists idx_tugas_pinned_order
  on public.tugas (is_pinned desc, "position" asc, tenggat_waktu asc, id asc);

create index if not exists idx_tugas_pinned_only
  on public.tugas (is_pinned)
  where is_pinned = true;

-- ------------------------------------------------------
-- 3) RPC set_tugas_pin
--    SECURITY INVOKER (default) => RLS tetap berlaku.
--    Penguncian advisory mencegah dua pengguna mendapat posisi yang sama
--    saat menekan pin hampir bersamaan.
-- ------------------------------------------------------
create or replace function public.set_tugas_pin(
  p_tugas_id uuid,
  p_pinned boolean,
  p_position integer default null
)
returns public.tugas
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.tugas;
  v_next integer;
  v_position integer;
begin
  if v_uid is null then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'Permintaan harus memakai sesi login (admin atau guru).';
  end if;

  if p_pinned is null then
    raise exception 'invalid_payload' using errcode = '22023',
      hint = 'p_pinned wajib bernilai true atau false.';
  end if;

  -- Baca baris target. Bila RLS tidak mengizinkan, baris tidak terlihat dan
  -- fungsi berhenti dengan pesan yang jelas (bukan diam-diam sukses).
  select * into v_row from public.tugas where id = p_tugas_id;
  if not found then
    raise exception 'not_found' using errcode = 'P0002',
      hint = 'Tugas tidak ditemukan atau tidak dapat diakses oleh akun ini.';
  end if;

  -- Pemeriksaan ulang otorisasi di sisi server (bukan hanya RLS).
  if not (public.is_admin() or (public.is_guru() and v_row.guru_id = v_uid)) then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'Hanya admin atau guru pemilik tugas yang boleh mengubah pin.';
  end if;

  if p_pinned then
    if p_position is null then
      -- Serialisasi penentuan posisi agar tidak ada dua penulis yang membaca
      -- max(position) yang sama pada saat bersamaan.
      perform pg_advisory_xact_lock(hashtext('public.tugas.pin_position'));
      select coalesce(max("position"), -1) + 1
        into v_next
        from public.tugas
       where is_pinned = true;
      v_position := least(greatest(coalesce(v_next, 0), 0), 1000000);
    else
      v_position := least(greatest(p_position, 0), 1000000);
    end if;
  else
    -- Melepas pin: posisi dikembalikan ke 0 agar tidak menyisakan celah urutan.
    v_position := 0;
  end if;

  update public.tugas
     set is_pinned = p_pinned,
         "position" = v_position
   where id = p_tugas_id
  returning * into v_row;

  -- UPDATE ... RETURNING INTO pada 0 baris membuat v_row menjadi NULL dan
  -- FOUND = false. Keduanya diperiksa agar kegagalan RLS tidak pernah
  -- dilaporkan sebagai sukses.
  if not found or v_row.id is null then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'Perubahan ditolak oleh kebijakan keamanan baris.';
  end if;

  return v_row;
end;
$$;

comment on function public.set_tugas_pin(uuid, boolean, integer) is
  'Pin/unpin tugas. Otorisasi: admin atau guru pemilik tugas (dicek ulang di server). Posisi null = otomatis di akhir daftar pin.';

revoke all on function public.set_tugas_pin(uuid, boolean, integer) from public, anon;
grant execute on function public.set_tugas_pin(uuid, boolean, integer) to authenticated, service_role;

-- ------------------------------------------------------
-- 4) Muat ulang schema cache PostgREST
--    Agar kolom baru & RPC langsung dikenali tanpa restart.
-- ------------------------------------------------------
notify pgrst, 'reload schema';

-- ------------------------------------------------------
-- 5) Verifikasi manual (jalankan setelah migration)
-- ------------------------------------------------------
-- -- kolom ada?
-- select column_name, data_type, is_nullable, column_default
--   from information_schema.columns
--  where table_schema = 'public' and table_name = 'tugas'
--    and column_name in ('is_pinned', 'position');
--
-- -- fungsi ada?
-- select to_regprocedure('public.set_tugas_pin(uuid,boolean,integer)');
--
-- -- data lama aman?
-- select count(*) filter (where is_pinned) as dipin,
--        count(*) filter (where "position" <> 0) as posisi_non_nol,
--        count(*) as total
--   from public.tugas;
```

### 3.1 Petunjuk eksekusi manual

1. Buka **Supabase Dashboard → SQL Editor** untuk project EduTask.
2. Tempel seluruh isi `supabase/migrations/007_tugas_pin.sql`, jalankan.
3. Jalankan blok verifikasi di akhir berkas (kolom, `to_regprocedure`, jumlah
   baris lama). Hasil yang diharapkan:
   * 2 baris kolom `is_pinned` & `position`;
   * `public.set_tugas_pin(uuid,boolean,integer)` tidak `NULL`;
   * `posisi_non_nol = 0` pada data lama (belum ada yang mem-pin).
4. **(Opsional, disarankan)** Uji RPC dengan akun siswa lewat aplikasi: tombol
   pin memang tidak muncul, dan pemanggilan manual
   `rpc('set_tugas_pin', ...)` harus gagal `42501`.
5. Tidak ada rollback otomatis. Bila ingin membatalkan sepenuhnya:
   `drop function if exists public.set_tugas_pin(uuid,boolean,integer);`
   lalu `alter table public.tugas drop column if exists "position";`
   dan `drop column if exists is_pinned;` — **hanya** jika fitur benar-benar
   dibatalkan (menghapus kolom berarti kehilangan status pin).

---

## 4. Pin tugas

### 4.1 Kolom baru

| Kolom | Tipe | Default | Keterangan |
|---|---|---|---|
| `is_pinned` | `boolean not null` | `false` | Tugas muncul di atas daftar. |
| `position` | `integer not null` | `0` | Urutan manual di antara tugas yang di-pin (kecil = atas), dibatasi `0..1.000.000`. |

Sebelum migration ini **tidak ada** kolom pin/urutan di `public.tugas`
(sudah diaudit: `001`–`006` tidak memuatnya), jadi tidak ada duplikasi kolom.

### 4.2 Kontrak urutan (`TugasSorting`)

Urutan berlaku untuk daftar tugas admin, guru, dan siswa:

1. tugas **di-pin** selalu di atas;
2. di antara yang di-pin: `position` menaik;
3. tie-breaker: `tenggat_waktu` lebih awal;
4. lalu `created_at`;
5. lalu `id` (ascending) — menjamin hasil sama di setiap perangkat dan setiap
   pemuatan ulang.

Konsekuensi penting: **data lama tetap berurutan seperti sebelumnya** (tenggat
menaik), karena semua baris lama `is_pinned = false, position = 0`.

Laporan (CSV/PDF) **tidak** memakai urutan pin: `ReportDocument.from` selalu
mengurutkan berdasarkan tenggat lalu `id`, sehingga isi laporan tidak berubah
hanya karena admin mem-pin sesuatu.

### 4.3 Otorisasi

| Peran | Melihat menu pin | Efek pemanggilan RPC langsung |
|---|---|---|
| Admin | Ya (semua tugas) | Diizinkan (policy `Admin manage tugas` + cek `is_admin()`). |
| Guru pemilik | Ya | Diizinkan (policy `Guru manage own tugas` + cek `is_guru()` & `guru_id = auth.uid()`). |
| Guru lain | Tidak | Ditolak `42501` bila barisnya terlihat, atau `P0002` bila RLS menyembunyikan baris tersebut. |
| Siswa | Tidak | Ditolak `42501` (tidak ada policy UPDATE pada `tugas`). |
| Anon | Tidak | Ditolak `42501` (`auth.uid()` null). |

`AppError` menerjemahkan `42501` → “Akses ditolak”, `P0002` → “Data tidak
ditemukan”, dan `22023` → “Data tidak valid”, sehingga pengguna tidak melihat
kode mentah PostgREST.

`TugasPinPolicy` hanya menyaring UI. **Keamanan ada di server**: RLS `tugas`
yang sudah ada + pemeriksaan ulang di dalam `set_tugas_pin`. UI tersembunyi
tidak pernah dianggap kontrol.

### 4.4 Sinkronisasi state

* Admin: `setPin` → `_refresh()` (membangun ulang `FutureBuilder`).
* Guru: `setPin` → `ref.invalidate(teacherTasksProvider)`.
* Siswa: tidak ada aksi; lencana hanya informatif.
* Daftar diurutkan ulang dari `TugasSorting` setelah data diambil, sehingga
  urutan tidak bergantung pada cache lokal.

---

## 5. Ekspor PDF

### 5.1 Satu sumber data untuk CSV dan PDF

```
Supabase (fetchReport: kelas, guru, mapel, periode, limit)
        │
        ▼
List<TugasReportRow>
        │
        ▼
ReportDocument.from(...)   ← satu kali normalisasi + urutan + pembatasan
        ├── toTableRows()  → CsvBuilder.build()      → CSV
        └── ReportPdfBuilder.build() → berkas PDF    → PDF
```

* Header kolom: `Judul Tugas, Kelas, Mata Pelajaran, Guru, Tenggat, Total
  Siswa, Selesai, Belum, Terlambat, Persentase Selesai` — sama untuk CSV & PDF
  (kolom **Guru** ditambahkan agar filter guru konsisten; CSV ikut diperbarui).
* Filter halaman: kelas + **periode tenggat** (baru) → diterapkan pada query
  (`gte`/`lte` `tenggat_waktu`), bukan hanya di tampilan.
* Nama berkas `laporan-tugas-<kelas>-<periode>-<yyyyMMdd-HHmm>` dipakai untuk
  `.csv` dan `.pdf`; dibersihkan dari spasi/simbol.
* Batas aman: **500 baris** per dokumen (`ReportDocument.maxRows`); query
  dibatasi 501 baris (`limit` di server) agar laporan besar tidak menarik
  seluruh tabel, dan PDF mencetak catatan bila terpotong.

### 5.2 Template PDF

* A4 **landscape**, margin 26/22/26/24 pt, header tabel diulang setiap halaman.
* Identitas: `EduTask`, tagline dari `AppInfo` (tidak di-hardcode), judul
  laporan, waktu dibuat, cakupan filter, periode.
* Ringkasan statistik: total tugas, total siswa, selesai, terlambat,
  persentase agregat.
* Tabel: lebar kolom eksplisit (`columnWidths`), angka rata kanan, baris
  ganjil bergaris, border tipis — teks panjang membungkus, tidak terpotong.
* Footer: cakupan/periode + **"Halaman X dari Y"** dari `Context.pageNumber`
  dan `Context.pagesCount` saat halaman digambar.
* Kondisi khusus:
  * data kosong → kotak "Tidak ada data pada filter ini" (PDF tetap bisa
    diekspor sebagai bukti periode tanpa data);
  * data > 500 → catatan pemotongan di bawah tabel;
  * gagal membentuk/mengirim → pesan error di SnackBar, tombol kembali aktif.

### 5.3 Perilaku per platform

| Platform | Implementasi | Hasil |
|---|---|---|
| Android/iOS | `Printing.layoutPdf` (dialog cetak sistem) & `Printing.sharePdf` | Pratinjau, simpan sebagai PDF, cetak, atau bagikan. |
| Web | Blob `application/pdf` + `<a download>`; opsi "Buka untuk dicetak" membuka tab baru | Unduhan berkas PDF asli; cetak lewat penampil browser. |
| Lainnya | Stub | Pesan "tidak didukung", tanpa crash. |

Pemilihan implementasi memakai *conditional import* (`dart.library.io` /
`dart.library.js_interop`), sehingga tidak ada API Android yang bocor ke Web.
Web **tidak** memakai jalur `printing` (yang mengunduh pdf.js dari CDN
`unpkg.com`) — unduhan dibuat sendiri oleh aplikasi.

### 5.4 Status UI

`Ekspor CSV` dan `Ekspor PDF` memakai data yang sama dan sama-sama nonaktif
saat data masih dimuat atau sedang membentuk PDF. Tombol PDF menampilkan
indikator "Menyiapkan…" selama proses.

---

## 6. Kompatibilitas data lama

* `Tugas.fromJson` membaca `is_pinned`/`position` dengan parser toleran
  (bool, angka, `'true' | '1' | 't' | 'yes'`); nilai hilang/tidak valid →
  `false`/`0`.
* Tidak ada baris yang dihapus atau diubah bentuknya oleh migration.
* Aplikasi versi lama tetap berjalan: kolom baru punya default, dan
  `select *` lama tidak gagal.
* `Tugas.toJson()` tidak pernah menyertakan pin, sehingga `update()` biasa
  tidak bisa dipakai untuk mengubah pin dari klien.

---

## 7. Yang sengaja **tidak** diubah

* 508 penggunaan `AppColors.*` (tidak ada migrasi massal).
* Alur autentikasi, `applicationId`, signing key, dan skema RLS lain.
* Lima rute dengan AppBar ganda (masalah kosmetik lama, di luar lingkup).
* Tidak ada tabel baru: fitur pin cukup memakai `public.tugas`.

---

## 8. Cara memverifikasi manual

### 8.1 Pin (setelah migration dijalankan)

1. Login admin → menu **Tugas** → titik tiga pada satu tugas → **Sematkan ke
   atas**. Tugas naik ke urutan pertama dan muncul lencana "Disematkan".
2. Login guru pemilik tugas → menu **Kelola Tugas** → menu yang sama tersedia.
3. Login guru **lain** → menu pin tidak muncul. (Uji negatif: memanggil RPC
   manual dari akun itu harus `42501`.)
4. Login siswa → hanya lencana "Disematkan" tanpa aksi.
5. Lepas sematan → tugas kembali ke urutan tenggat semula.
6. Buka aplikasi versi lama (sebelum update) → daftar tugas tetap tampil.

### 8.2 PDF

1. Admin → **Laporan** → pilih kelas dan periode → **Ekspor PDF**.
2. Android: dialog cetak muncul → "Simpan sebagai PDF" → berkas bisa dibuka.
3. Web: berkas `.pdf` terunduh (bukan tab kosong), atau "Buka untuk dicetak"
   membuka PDF di tab baru.
4. Bandingkan isi PDF dengan CSV pada filter yang sama: jumlah baris, nilai
   kolom, dan total statistik harus identik.
5. Uji filter tanpa data → PDF berisi kotak "Tidak ada data pada filter ini".

---

## 9. Hasil verifikasi

Diuji lewat GitHub Actions pada branch `arena/860055b9-aplikasioo`, commit
**`ecc2af2`** (PR #66) — commit terakhir yang mengubah kode. Tidak ada
pemeriksaan di bawah ini yang dijalankan di laptop pengembang; semuanya berasal
dari CI.

| Pemeriksaan | Status | Hasil |
|---|---|---|
| Parser sintaks Dart (`lib` + `test`) | **SELESAI (lokal)** | 145 berkas, 0 kesalahan sintaks. |
| Parser SQL 7 migration | **SELESAI (lokal)** | 7/7 lolos `pgsql-parser`. |
| `flutter pub get` | **TERVERIFIKASI CI** | Sukses (job `analyze-test`, `web-build`, `build`). |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **TERVERIFIKASI CI** | **0 error, 0 warning, 4 info** (semuanya info lama di `back_guard.dart` & `session_guard.dart`, bukan dari ronde ini). |
| `flutter test` | **TERVERIFIKASI CI** | **210 tes lulus** (sebelumnya 162; +48 tes baru ronde ini: 42 fitur, 3 pemetaan error, 3 konsistensi CSV ↔ PDF + label periode). |
| `flutter build web --release` | **TERVERIFIKASI CI** | Sukses (job `web-build` hijau). Pemeriksaan artefak lolos: `index.html`, `manifest.json`, `flutter_bootstrap.js`, `main.dart.js`, `flutter_service_worker.js`, ikon 192 px ada; teks `EduTask` ada di `index.html`; **tidak ada** string `service_role` di bundle. Ukuran pasti tidak ditampilkan di komentar PR (ada di log job). |
| `flutter build apk --release` | **TERVERIFIKASI CI** | **APK build #96** sukses: universal 67 MB (versionCode 96), arm64-v8a 27 MB (2096), armeabi-v7a 25 MB (1096), x86_64 28 MB (4096); `applicationId com.edutask.sekolah`, `minSdk 24`, `targetSdk 36`, ditandatangani kunci uji yang sama (`f3d985e4…ffcbf9`). |
| `install-test` (emulator x86_64) | **GAGAL — INFRASTRUKTUR CI** | Terjadi pada setiap percobaan (#91, #93, #96, #98): emulator tidak menghasilkan log smoke test (`emulator gagal boot / action gagal sebelum skrip`). Langkah ini memakai `continue-on-error`, jadi job tetap hijau, tetapi **instalasi APK belum terbukti** lewat CI. |
| Uji pin/PDF manual di perangkat nyata | **BELUM TERVERIFIKASI** | Butuh perangkat + database live. |
| Uji di browser nyata | **BELUM TERVERIFIKASI** | Butuh browser + Supabase live. |
| Migration di database produksi | **BELUM DIJALANKAN** | Jalankan manual (bagian 3.1). |

Detail APK build #96 (`SHA256SUMS.txt` lengkap ada di komentar PR):

| File | Ukuran | versionCode | SHA-256 |
|---|---|---|---|
| `EduTask-1.2.0-arm64-v8a.apk` | 27 MB | 2096 | `eeb860b35f58c77539059aa503371ca882075b854b82949be19717a4a0246a49` |
| `EduTask-1.2.0-armeabi-v7a.apk` | 25 MB | 1096 | `b8514956f63ba02386226c6613a27a8a412ccfc2740c1440b898191243831d86` |
| `EduTask-1.2.0-universal.apk` | 67 MB | 96 | `ee24d96917b18a5de34e934279ee6c889d967ad2c267fac8f0e100c82dcf9ed4` |
| `EduTask-1.2.0-x86_64.apk` | 28 MB | 4096 | `b7f90825c05cd6bfe3e25a73d885f7da148078a5adb983f613426ab369e3e87f` |

> APK pada build #96 adalah artefak **job CI** (bisa diunduh dari halaman run
> Actions). Release `latest-apk` belum diperbarui karena workflow APK hanya
> memublikasikan release saat push ke `main` — yaitu setelah PR ini digabung.

Catatan penting soal `install-test`: pada build #91, #93, #96, dan #98 langkah emulator **gagal**
(emulator tidak boot / action gagal sebelum skrip dijalankan) sehingga tidak ada
bukti instalasi dari CI. Karena langkah itu `continue-on-error: true`, status
job tetap hijau — angka "hijau" di atas **tidak** boleh dibaca sebagai bukti
APK berjalan. Uji instalasi manual di perangkat tetap diperlukan (bagian 8).

### 9.1 Bug yang ditemukan CI dan diperbaiki

CI pertama (run `40437069068` / `40437069063`) gagal dan mengungkap satu bug
nyata yang **tidak bisa dilihat dengan parser lokal**:

```
image-4.11.0/lib/src/formats/png_decoder.dart:377:39:
Error: The method 'decodeLazy' isn't defined for the type 'ZLibDecoder'.
 - 'ZLibDecoder' is from 'package:archive-4.0.9/...'
```

* **Akar masalah:** `pdf` membatasi `archive >=3.4.0 <4.1.0`, sedangkan
  `image` 4.11.0 memanggil `ZLibDecoder.decodeLazy` yang baru ada di
  `archive >=4.1.0`. Kombinasi ini lolos resolusi versi tetapi gagal saat
  kompilasi (dart2js dan kernel test).
* **Dampak:** `flutter build web` gagal total, dan satu berkas tes
  (`report_pdf_builder_test`) gagal dimuat di VM sehingga 5 tes tidak berjalan.
* **Perbaikan:** `image: '>=4.10.0 <4.11.0'` di `pubspec.yaml` (4.10.x memakai
  `decodeBytes`, aman dengan `archive 4.0.9`). Komentar di pubspec menjelaskan
  alasan dan kapan pin ini boleh dilepas.
* **Bukti:** setelah pin, `analyze` 0 error, `flutter test` 210 lulus,
  `build web` sukses, `build apk` sukses.

### 9.2 Perbaikan diagnosa CI

Agar kegagalan berikutnya tidak perlu menebak, `verify.yml` sekarang:

* menulis ringkasan blok `[E]` dari `flutter test` ke komentar PR
  (`### Tes yang gagal (ringkas)`); pola grep diperluas ke `Expected:`,
  `Actual:`, `Which:`, `TimeoutException`, `Failed to load`, dan
  `Some tests failed` karena kegagalan *ekspektasi* tidak selalu memakai
  penanda `[E]`.
* menulis 12 KB terakhir log `flutter build web` ke komentar PR
  (`### Kegagalan flutter build web`),
* memakai komentar terpisah (bukan `--edit-last`) supaya job `analyze-test` dan
  `web-build` tidak saling menimpa komentar.

### 9.3 Kegagalan tes konsistensi CSV ↔ PDF (dan perbaikannya)

Commit `4d25b72` membuat dua job merah (`analyze-test` **dan** `build` — keduanya
menjalankan `flutter test`). Gejala di komentar PR menyesatkan: hanya baris ✅
yang terlihat dan grep `[E]` kosong, karena ringkasan hanya menangkap blok `[E]`
sementara kegagalan *ekspektasi* ditulis sebagai baris `Expected: contains …`.

* **Akar masalah (bukan bug aplikasi):** tes baru menegaskan `40.0%` untuk baris
  dengan 20 selesai dari 30 siswa. Rumus `TugasReportRow.persen` adalah
  `selesai / total × 100`, jadi nilai benarnya **66.7%**; baris kedua
  15/30 = **50.0%**.
* **Perbaikan:** ekspektasi tes dibetulkan menjadi `66.7%` dan `50.0%` (dengan
  komentar asal angkanya). Tidak ada kode produksi ronde ini yang diubah dan
  tidak ada tes yang dihapus atau dilonggarkan.
* **Pencegahan:** `verify.yml` kini menyertakan `Expected:`/`Actual:`/`Which:`
  di ringkasan kegagalan sehingga nama tes + nilai yang diharapkan langsung
  terlihat di komentar PR.
* **Bukti:** commit `ecc2af2` → `analyze-test` hijau (**210 tes lulus**),
  `build` hijau (**build #96**), `web-build` hijau.

### 9.4 Unduh APK pratinjau (untuk uji di perangkat)

Artifact GitHub Actions memerlukan login dan berbentuk `.zip`, sedangkan
release `latest-apk` hanya diperbarui saat push ke `main`. Karena itu job
`build` sekarang juga memublikasikan **pre-release** `preview-apk` dari branch
PR (langkah `Publikasikan APK pratinjau (bukan main)`), sehingga APK bisa
diunduh langsung sebagai berkas `.apk` tanpa login. Release `latest-apk`
tidak tersentuh.

**Halaman release:** <https://github.com/HOOOOOOQ/aplikasioo/releases/tag/preview-apk>

| Perangkat | Berkas | Unduh |
|---|---|---|
| HP Android modern (disarankan) | `EduTask-1.2.0-arm64-v8a.apk` — 27 MB | <https://github.com/HOOOOOOQ/aplikasioo/releases/download/preview-apk/EduTask-1.2.0-arm64-v8a.apk> |
| HP Android 32-bit lama | `EduTask-1.2.0-armeabi-v7a.apk` — 25 MB | <https://github.com/HOOOOOOQ/aplikasioo/releases/download/preview-apk/EduTask-1.2.0-armeabi-v7a.apk> |
| Semua ABI dalam satu berkas | `EduTask-1.2.0-universal.apk` — 67 MB | <https://github.com/HOOOOOOQ/aplikasioo/releases/download/preview-apk/EduTask-1.2.0-universal.apk> |
| Emulator x86_64 | `EduTask-1.2.0-x86_64.apk` — 28 MB | <https://github.com/HOOOOOOQ/aplikasioo/releases/download/preview-apk/EduTask-1.2.0-x86_64.apk> |
| Checksum | `SHA256SUMS.txt` | <https://github.com/HOOOOOOQ/aplikasioo/releases/download/preview-apk/SHA256SUMS.txt> |

Isi pratinjau (kode yang sama dengan commit `ecc2af2` — commit setelahnya hanya
dokumentasi/CI): `com.edutask.sekolah`, versionName 1.2.0, minSdk 24,
targetSdk 36, signature v2 + v3 dengan keystore uji (`f3d985e4…ffcbf9`).
Berkas pratinjau **ditimpa setiap build baru** di branch ini (nomor build
tercetak di judul release dan di `versionCode` APK); tautan di atas tetap sama
karena memakai tag `preview-apk`.

> Pratinjau ini **belum lolos uji instalasi otomatis** (langkah `install-test`
> di CI masih gagal karena emulator, lihat tabel §9) dan **migration 007 belum
> dijalankan**. Setelah memasang APK: ekspor PDF bisa langsung dicoba, tetapi
> tombol semat akan menampilkan pesan error sampai SQL §3 dijalankan.

---

## 10. Catatan lingkungan

Pemeriksaan lokal yang bisa dijalankan tanpa Flutter SDK:

* `node /tmp/tools/dartcheck.cjs lib test` — parser Dart (tree-sitter) untuk
  memastikan tidak ada kesalahan sintaks.
* `node /tmp/tools/checksql.cjs` — parser SQL untuk seluruh isi
  `supabase/migrations/`.

Keduanya **bukan** pengganti `flutter analyze`: kesalahan tipe tidak terdeteksi
di lokal dan baru terlihat di CI.

---

## 11. Risiko & batasan yang diketahui

1. Migration **belum dijalankan** → tombol pin akan gagal (`P0002`/`42501`)
   sampai SQL dijalankan; UI menampilkan pesan error, bukan diam. Fitur PDF
   tidak bergantung pada migration dan sudah lolos build di CI.
2. Bila `position` diubah manual di luar aplikasi hingga melebihi 1.000.000,
   constraint `check_tugas_position` menolak (data lama tidak terpengaruh
   karena `NOT VALID`).
3. Urutan manual (drag & drop) **belum** ada di UI; RPC sudah menerima
   `p_position` sehingga penambahan UI reorder tidak memerlukan migration baru.
   Mekanisme aman untuk reorder sudah tersedia: `p_position` + advisory lock
   saat posisi otomatis.
4. PDF memakai font standar Helvetica (bawaan PDF) — tidak ada unduhan font,
   tetapi karakter di luar Latin-1 bisa tampil tidak sempurna.
5. Web: unduhan bergantung pada dukungan browser terhadap
   `URL.createObjectURL` + atribut `download` (Chrome/Edge/Firefox/Safari
   modern mendukungnya).
