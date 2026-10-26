import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../shared/repositories/akun_repository.dart';

class AdminAuditPage extends ConsumerStatefulWidget {
  const AdminAuditPage({super.key});

  @override
  ConsumerState<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends ConsumerState<AdminAuditPage> {
  late Future<List<AuditEntry>> _future;
  String? _entityFilter;
  String? _actionFilter;
  int _visible = 25;
  static const int _pageSize = 25;

  static const Map<String, String> _entities = {
    'tugas': 'Tugas',
    'siswa': 'Siswa',
    'kelas': 'Kelas',
    'mata_pelajaran': 'Mapel',
    'jadwal_pelajaran': 'Jadwal',
    'profiles': 'Akun',
    'kode_akses_siswa': 'Kode akses',
  };

  @override
  void initState() {
    super.initState();
    _future = ref.read(akunRepositoryProvider).fetchAudit(limit: 200);
  }

  Future<void> _refresh() async {
    setState(() => _future = ref.read(akunRepositoryProvider).fetchAudit(limit: 200));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AuditEntry>>(
          future: _future,
          builder: (context, snapshot) {
            var list = snapshot.data ?? const <AuditEntry>[];
            if (_entityFilter != null) {
              list = list.where((e) => e.entity == _entityFilter).toList();
            }
            if (_actionFilter != null) {
              list = list.where((e) => e.action == _actionFilter).toList();
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                AppHeroHeader(
                  compact: true,
                  eyebrow: 'Jejak aktivitas',
                  title: 'Audit Log',
                  subtitle: '${snapshot.data?.length ?? 0} perubahan terakhir tercatat otomatis oleh database.',
                ),
                const SizedBox(height: AppSpacing.lg),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _entityFilter == null && _actionFilter == null,
                        onSelected: (_) => setState(() {
                          _entityFilter = null;
                          _actionFilter = null;
                          _visible = _pageSize;
                        }),
                      ),
                      for (final entry in _entities.entries) ...[
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _entityFilter == entry.key,
                          onSelected: (selected) => setState(() {
                            _entityFilter = selected ? entry.key : null;
                            _visible = _pageSize;
                          }),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.md),
                      DropdownButton<String?>(
                        value: _actionFilter,
                        hint: const Text('Aksi', style: TextStyle(fontSize: 12)),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Semua aksi')),
                          DropdownMenuItem(value: 'insert', child: Text('Tambah')),
                          DropdownMenuItem(value: 'update', child: Text('Ubah')),
                          DropdownMenuItem(value: 'delete', child: Text('Hapus')),
                          DropdownMenuItem(value: 'issue', child: Text('Terbitkan kode')),
                          DropdownMenuItem(value: 'revoke', child: Text('Cabut kode')),
                        ],
                        onChanged: (value) => setState(() {
                          _actionFilter = value;
                          _visible = _pageSize;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const AppSkeletonList(count: 5)
                else if (snapshot.hasError)
                  AppErrorState(error: snapshot.error, onRetry: _refresh)
                else if (list.isEmpty)
                  const AppCard(
                    child: AppEmptyState(
                      icon: Icons.history_rounded,
                      title: 'Belum ada aktivitas',
                      subtitle: 'Perubahan data oleh admin dan guru akan muncul di sini.',
                    ),
                  )
                else
                  ...list.take(_visible).map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _colorFor(entry.action).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Icon(_iconFor(entry.action), size: 17, color: _colorFor(entry.action)),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.actionLabel} ${entry.entityLabel}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${entry.actorName ?? (entry.actorId.isEmpty ? 'Sistem' : 'Pengguna')}'
                                      ' • ${entry.actorRole} • ${AppDateUtils.formatTanggalJam(entry.createdAt)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    if (entry.detail['changed'] is Map &&
                                        (entry.detail['changed'] as Map).isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Kolom: ${(entry.detail['changed'] as Map).keys.join(', ')}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                if (list.length > _visible)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _visible += _pageSize),
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      label: Text('Muat lebih banyak (${list.length - _visible} lagi)'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'insert':
        return Icons.add_rounded;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'issue':
        return Icons.key_rounded;
      case 'revoke':
        return Icons.block_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _colorFor(String action) {
    switch (action) {
      case 'insert':
      case 'issue':
        return AppColors.success;
      case 'update':
        return AppColors.info;
      case 'delete':
      case 'revoke':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
