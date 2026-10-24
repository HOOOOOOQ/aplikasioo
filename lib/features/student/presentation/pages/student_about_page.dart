import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class StudentAboutPage extends StatelessWidget {
  const StudentAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/siswa'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.school, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('EduTask', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Text('Aplikasi Tugas & Jadwal Pelajaran Sekolah', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)), child: const Text('Versi 1.0.0 • com.edutask.sekolah', style: TextStyle(fontSize: 12, color: AppColors.primary))),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.primary),
                title: const Text('Tentang Aplikasi', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('EduTask membantu siswa melihat jadwal pelajaran dan tugas dari guru secara online. Admin dan guru mengelola data melalui dashboard terpisah.', style: TextStyle(fontSize: 12)),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.security, color: AppColors.success),
                title: const Text('Keamanan'),
                subtitle: const Text('Siswa tidak perlu login. Status tugas yang resmi memerlukan kode identitas siswa yang diberikan sekolah. Data sensitif dilindungi RLS Supabase.', style: TextStyle(fontSize: 12)),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language, color: AppColors.info),
                title: const Text('Zona Waktu'),
                subtitle: const Text('Semua waktu ditampilkan dalam zona Asia/Jakarta. Notifikasi tenggat 24 jam & 1 jam sebelum jika diaktifkan.', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Dibuat dengan Flutter • Material 3 • Supabase', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
