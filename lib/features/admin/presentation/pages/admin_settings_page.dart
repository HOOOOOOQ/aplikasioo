import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/supabase_config.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pengaturan'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_done, color: AppColors.primary),
              title: const Text('Status Supabase'),
              subtitle: Text(SupabaseConfig.isConfigured ? 'Terhubung: ${SupabaseConfig.supabaseUrl}' : 'Belum dikonfigurasi — gunakan --dart-define'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informasi Aplikasi', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _row('Nama', 'EduTask'),
                  _row('Package', 'com.edutask.sekolah'),
                  _row('Versi', '1.0.0+1'),
                  _row('Flutter', 'Stable 3.24.x'),
                  _row('AGP', '8.3.0 • Gradle 8.7 • Java 17'),
                  _row('Supabase', 'supabase_flutter ^2.5.6'),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Keamanan', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('• Service role key tidak pernah di APK\n• RLS aktif di semua tabel\n• Role diverifikasi di server (profiles.role)\n• Edge Functions untuk operasi admin & identitas siswa', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          const Text(': '),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
