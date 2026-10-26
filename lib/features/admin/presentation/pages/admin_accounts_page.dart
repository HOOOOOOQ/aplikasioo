import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_error.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../shared/repositories/akun_repository.dart';
import '../../../auth/presentation/auth_provider.dart';

class AdminAccountsPage extends ConsumerStatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  ConsumerState<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends ConsumerState<AdminAccountsPage> {
  final TextEditingController _searchC = TextEditingController();
  late Future<List<ProfileRow>> _future;
  String _search = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _future = ref.read(akunRepositoryProvider).fetchProfiles();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = ref.read(akunRepositoryProvider).fetchProfiles(role: _roleFilter));
    await _future;
  }

  Future<void> _toggleActive(ProfileRow profile) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me?.id == profile.id) {
      showAppSnackBar(context, 'Anda tidak dapat menonaktifkan akun sendiri.', isError: true);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: profile.isActive ? 'Nonaktifkan akun?' : 'Aktifkan akun?',
      content: profile.isActive
          ? '${profile.fullName} tidak akan bisa login setelah dinonaktifkan.'
          : '${profile.fullName} akan dapat login kembali.',
      confirmLabel: profile.isActive ? 'Nonaktifkan' : 'Aktifkan',
      isDestructive: profile.isActive,
    );
    if (!confirmed) return;
    try {
      await ref.read(akunRepositoryProvider).setActive(profile.id, !profile.isActive);
      if (!mounted) return;
      showAppSnackBar(context, 'Status akun diperbarui.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  Future<void> _changeRole(ProfileRow profile) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me?.id == profile.id) {
      showAppSnackBar(context, 'Peran akun sendiri tidak dapat diubah dari sini.', isError: true);
      return;
    }
    final target = profile.role == 'admin' ? 'guru' : 'admin';
    final confirmed = await showConfirmDialog(
      context,
      title: target == 'admin' ? 'Jadikan admin?' : 'Jadikan guru?',
      content: target == 'admin'
          ? '${profile.fullName} akan memiliki akses penuh ke seluruh data sekolah.'
          : '${profile.fullName} akan kehilangan akses administratif dan hanya dapat mengelola tugas/kelasnya.',
      confirmLabel: 'Ubah peran',
      isDestructive: target == 'guru',
    );
    if (!confirmed) return;
    try {
      await ref.read(akunRepositoryProvider).setRole(profile.id, target);
      if (!mounted) return;
      showAppSnackBar(context, 'Peran diperbarui menjadi ${target == 'admin' ? 'Admin' : 'Guru'}.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppError.from(e).shortMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ProfileRow>>(
          future: _future,
          builder: (context, snapshot) {
            var list = snapshot.data ?? const <ProfileRow>[];
            if (_search.trim().isNotEmpty) {
              final needle = _search.trim().toLowerCase();
              list = list
                  .where((p) =>
                      p.fullName.toLowerCase().contains(needle) ||
                      p.email.toLowerCase().contains(needle))
                  .toList();
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Keamanan akun',
                  title: 'Akun & Role',
                  subtitle: '${list.where((p) => p.role == 'admin').length} admin • '
                      '${list.where((p) => p.role == 'guru').length} guru',
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppNotice.warning(
                  title: 'Perubahan sensitif',
                  text: 'Mengubah peran atau menonaktifkan akun langsung memengaruhi akses data. '
                      'Anda tidak dapat mengubah akun sendiri untuk mencegah terkunci dari dashboard.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSearchField(
                  controller: _searchC,
                  hint: 'Cari nama atau email…',
                  onChanged: (value) => setState(() => _search = value),
                  trailing: DropdownButton<String?>(
                    value: _roleFilter,
                    hint: const Text('Semua', style: TextStyle(fontSize: 12)),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Semua')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'guru', child: Text('Guru')),
                    ],
                    onChanged: (value) {
                      setState(() => _roleFilter = value);
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 4)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (list.isEmpty)
                  const AppCard(
                    child: AppEmptyState(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Tidak ada akun',
                      subtitle: 'Ubah filter atau undang guru lebih dulu.',
                    ),
                  )
                else
                  ...list.map((profile) {
                    final isMe = me?.id == profile.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            InitialsAvatar(
                              name: profile.fullName,
                              size: 42,
                              color: profile.role == 'admin' ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          isMe ? '${profile.fullName} (Anda)' : profile.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      _badge(profile.roleLabel,
                                          profile.role == 'admin' ? AppColors.primary : AppColors.textSecondary),
                                      if (!profile.isActive) ...[
                                        const SizedBox(width: 4),
                                        _badge('Nonaktif', AppColors.error),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !isMe,
                              onSelected: (value) {
                                if (value == 'toggle') _toggleActive(profile);
                                if (value == 'role') _changeRole(profile);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(profile.isActive ? 'Nonaktifkan akun' : 'Aktifkan akun'),
                                ),
                                PopupMenuItem(
                                  value: 'role',
                                  child: Text(profile.role == 'admin' ? 'Jadikan guru' : 'Jadikan admin'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
