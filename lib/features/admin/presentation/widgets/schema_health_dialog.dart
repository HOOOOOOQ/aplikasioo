import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/schema_health.dart';
import '../../../../core/utils/app_error.dart';

/// Buka dialog pemeriksaan skema (`edutask_schema_health()`).
///
/// Fungsi database tersebut hanya memberi hasil untuk admin; guru yang mencoba
/// akan menerima pesan "tidak berwenang" dari server — aplikasi tidak
/// menyembunyikan batasan itu.
Future<void> showSchemaHealthDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SchemaHealthDialog(),
  );
}

class _SchemaHealthDialog extends ConsumerStatefulWidget {
  const _SchemaHealthDialog();

  @override
  ConsumerState<_SchemaHealthDialog> createState() => _SchemaHealthDialogState();
}

class _SchemaHealthDialogState extends ConsumerState<_SchemaHealthDialog> {
  late Future<SchemaHealth> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(schemaHealthServiceProvider).check();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.health_and_safety_outlined, size: 30, color: AppColors.primary),
      title: const Text('Kesehatan skema'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<SchemaHealth>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              final error = AppError.from(snapshot.error!);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(error.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(error.message),
                  if (error.hint != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      error.hint!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              );
            }

            final health = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        health.isHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        size: 20,
                        color: health.isHealthy ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          health.isHealthy ? 'Skema lengkap' : 'Skema belum lengkap',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Versi: ${health.version}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                  ),
                  if (health.issues.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    for (final issue in health.issues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $issue', style: const TextStyle(fontSize: 12)),
                      ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Semua tabel inti ada, kolom wajib lengkap, dan RLS aktif.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  if (health.anonCanSelectSiswa) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Catatan: peran anon masih dapat membaca daftar siswa (dibutuhkan alur '
                      'pemilihan identitas siswa). Pastikan policy-nya hanya kolom non-sensitif.',
                      style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: () => setState(() => _future = ref.read(schemaHealthServiceProvider).check()),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Periksa lagi'),
        ),
      ],
    );
  }
}
