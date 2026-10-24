import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/auth_provider.dart';

class TeacherProfilePage extends ConsumerWidget {
  const TeacherProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profil'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(radius: 40, backgroundColor: AppColors.primaryContainer, child: Icon(Icons.person, size: 40, color: AppColors.primary)),
                    const SizedBox(height: 12),
                    Text(user?.fullName ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(user?.email ?? '-', style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text(user?.role.label ?? '-', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
