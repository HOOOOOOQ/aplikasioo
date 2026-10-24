import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'student_identity_provider.dart';

class StudentIdentityPage extends ConsumerStatefulWidget {
  const StudentIdentityPage({super.key});

  @override
  ConsumerState<StudentIdentityPage> createState() => _StudentIdentityPageState();
}

class _StudentIdentityPageState extends ConsumerState<StudentIdentityPage> {
  final _codeC = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeC.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeC.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, 'Masukkan kode siswa', isError: true);
      return;
    }
    setState(() => _loading = true);
    final ok = await ref.read(studentIdentityProvider.notifier).verifyAndSave(code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      showAppSnackBar(context, 'Identitas berhasil diverifikasi');
      Navigator.pop(context);
    } else {
      showAppSnackBar(context, 'Kode tidak ditemukan. Hubungi wali kelas.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Identitas Siswa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.info_outline, color: AppColors.primary), SizedBox(width: 8), Text('Tentang Kode Siswa', style: TextStyle(fontWeight: FontWeight.w600))]),
                  const SizedBox(height: 8),
                  const Text(
                    'Kode siswa diberikan oleh sekolah/wali kelas. Dengan memasukkan kode, kamu bisa menandai tugas sebagai selesai dan laporan akan terlihat oleh guru.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Text(
                      'Alternatif: Jika sekolah belum membagikan kode, kamu tetap bisa melihat jadwal & tugas, tetapi status selesai hanya tersimpan di perangkat ini (tidak menjadi laporan resmi).',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (identity.isIdentified)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.verified_user, color: AppColors.success, size: 40),
                      const SizedBox(height: 8),
                      const Text('Identitas Terverifikasi', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(identity.siswaNama ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Kelas: ${identity.kelasNama ?? identity.kelasId ?? "-"}', style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await ref.read(studentIdentityProvider.notifier).clear();
                          if (mounted) showAppSnackBar(context, 'Identitas dihapus. Status lokal tetap tersimpan.');
                          setState(() {});
                        },
                        child: const Text('Hapus Identitas'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              const Text('Masukkan Kode Siswa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeC,
                decoration: const InputDecoration(labelText: 'Kode Akses', hintText: 'Contoh: SISWA-001', prefixIcon: Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verifikasi'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Kode bersifat rahasia. Jangan bagikan ke siswa lain.', style: TextStyle(fontSize: 12, color: AppColors.textTertiary), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
