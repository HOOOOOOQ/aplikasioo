import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_info.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/platform_capabilities.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_header.dart';

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const List<_FaqItem> _adminFaq = [
  _FaqItem(
    'Kode akses siswa tidak bisa dibuat',
    'Pastikan Anda masuk sebagai admin atau guru dan sudah ditugaskan pada kelas tersebut. '
        'Jika muncul pesan "skema belum siap", jalankan migration 006 di Supabase lalu buka '
        'Pengaturan → Periksa skema database.',
  ),
  _FaqItem(
    'Kode terbit tetapi siswa tidak bisa memakainya',
    'Periksa status kode di halaman Kode Akses: aktif, belum kedaluwarsa, belum dicabut, dan '
        'sesuai kelas siswa. Kode sekali pakai otomatis nonaktif setelah dipakai satu siswa.',
  ),
  _FaqItem(
    'Lampiran gagal diunggah',
    'Lampiran disimpan di bucket privat. Upload memerlukan file tugas yang sudah tersimpan '
        'dan ukuran maksimal 10 MB dengan tipe PDF, DOC/DOCX, PPT/PPTX, XLS/XLSX, JPG/PNG, '
        'TXT, ZIP, atau RAR.',
  ),
  _FaqItem(
    'Muncul pesan sesi berakhir',
    'Sesi hanya dianggap berakhir bila server menolak refresh token. Gangguan jaringan '
        'ditampilkan sebagai masalah koneksi, bukan sesi berakhir. Masuk kembali untuk melanjutkan.',
  ),
];

const List<_FaqItem> _guruFaq = [
  _FaqItem(
    'Bagaimana menilai jawaban siswa?',
    'Buka Tugas → pilih tugas → bagian "Jawaban siswa", lalu tekan Beri nilai. Nilai 0–100 dan '
        'umpan balik akan langsung terlihat oleh siswa yang bersangkutan.',
  ),
  _FaqItem(
    'Siswa tidak muncul di daftar kelas',
    'Daftar kelas diambil dari jadwal mengajar dan wali kelas. Minta admin menambahkan jadwal '
        'atau menetapkan Anda sebagai wali kelas.',
  ),
  _FaqItem(
    'Bagaimana membuka grup kelas?',
    'Buka menu Chat → tombol Baru → pilih kelas. Grup dibuat sekali per kelas, dan pesan hanya '
        'dapat dibaca anggota grup serta guru yang mengampu kelas tersebut.',
  ),
];

const List<_FaqItem> _siswaFaq = [
  _FaqItem(
    'Apa itu kode akses?',
    'Kode akses diberikan guru atau admin untuk menghubungkan identitas Anda. Setelah terhubung, '
        'Anda dapat mengirim jawaban tugas, melihat nilai, dan mengikuti chat.',
  ),
  _FaqItem(
    'Kode akses saya ditolak',
    'Periksa apakah kode sudah kedaluwarsa, sudah dipakai, atau bukan untuk kelas Anda. Minta '
        'kode baru kepada guru. Kode tidak dapat dipakai ulang setelah berhasil.',
  ),
  _FaqItem(
    'Mengapa pengingat tenggat tidak muncul?',
    'Pengingat lokal hanya tersedia di aplikasi Android. Di Web, gunakan halaman Notifikasi dan '
        'kalender tenggat untuk memantau tugas.',
  ),
  _FaqItem(
    'Apakah saya bisa memakai aplikasi tanpa kode akses?',
    'Bisa. Jadwal dan daftar tugas dapat dilihat tanpa login. Kode akses hanya diperlukan untuk '
        'fitur yang membutuhkan identitas resmi (pengumpulan, nilai, chat).',
  ),
];

/// Halaman Bantuan & FAQ.
///
/// Isi disesuaikan dengan peran yang sedang membuka halaman. Tidak memuat
/// kredensial, email admin, atau kode akses apa pun.
class HelpPage extends StatelessWidget {
  /// 'admin' | 'guru' | 'siswa'
  final String role;
  final String fallbackRoute;

  const HelpPage({
    super.key,
    this.role = 'siswa',
    this.fallbackRoute = '/siswa',
  });

  List<_FaqItem> get _items => switch (role) {
        'admin' => [..._adminFaq, ..._guruFaq],
        'guru' => [..._guruFaq, ..._siswaFaq],
        _ => _siswaFaq,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bantuan & FAQ'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go(fallbackRoute),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          const AppHeroHeader(
            eyebrow: 'Panduan EduTask',
            title: 'Butuh bantuan?',
            subtitle: 'Jawaban singkat untuk pertanyaan yang paling sering muncul.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Langkah cepat', icon: Icons.bolt_rounded),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step(number: 1, text: 'Admin/guru masuk dengan akun yang diberikan pengelola sekolah.'),
                _Step(number: 2, text: 'Siswa memilih "Lanjut sebagai siswa" lalu memasukkan kode akses dari guru.'),
                _Step(number: 3, text: 'Lihat jadwal, daftar tugas, dan pengumuman di beranda.'),
                _Step(number: 4, text: 'Kumpulkan jawaban tugas sebelum tenggat, lalu pantau nilai di detail tugas.'),
                _Step(number: 5, text: 'Gunakan chat untuk bertanya kepada guru pengampu.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Pertanyaan umum', icon: Icons.quiz_outlined),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    title: Text(
                      item.question,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.answer,
                          style: const TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Masih butuh bantuan?', icon: Icons.contact_support_rounded),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hubungi admin atau guru yang mengelola EduTask di sekolah Anda untuk masalah akun, '
                  'kode akses, atau data kelas.',
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/tentang'),
                      icon: const Icon(Icons.info_outline_rounded, size: 17),
                      label: const Text('Tentang EduTask'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            color: AppColors.infoContainer,
            border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            child: Row(
              children: [
                const Icon(Icons.devices_rounded, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Anda membuka EduTask di ${PlatformCapabilities.label}. '
                    '${NotificationServiceNote.text}',
                    style: const TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              '${AppInfo.teamMotto} • ${AppInfo.copyright}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keterangan singkat kapabilitas notifikasi per platform (bebas dari plugin).
class NotificationServiceNote {
  static String get text => PlatformCapabilities.supportsLocalNotifications
      ? 'Pengingat tenggat dapat dijadwalkan di perangkat ini.'
      : 'Pengingat tenggat lokal hanya tersedia di aplikasi Android.';
}
