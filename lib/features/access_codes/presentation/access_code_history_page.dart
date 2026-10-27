import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/access_code.dart';

/// Riwayat terbit/klaim/cabut kode akses.
///
/// Membaca RPC `kode_akses_riwayat(int)` (migration 006) yang berjalan dengan
/// hak akses pengguna; RLS `kode_akses_siswa` tetap menentukan baris mana yang
/// boleh dilihat (admin semua, guru kelas yang diampu).
class AccessCodeHistoryPage extends ConsumerStatefulWidget {
  const AccessCodeHistoryPage({super.key});

  @override
  ConsumerState<AccessCodeHistoryPage> createState() => _AccessCodeHistoryPageState();
}

class _AccessCodeHistoryPageState extends ConsumerState<AccessCodeHistoryPage> {
  static const int _limit = 100;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = SupabaseService.tryClient;
    if (client == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum dikonfigurasi pada build ini.',
        code: 'config',
      );
    }
    try {
      final data = await client.rpc('kode_akses_riwayat', params: {'p_limit': _limit});
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return const [];
    } on PostgrestException catch (e) {
      throw AppError.from(e);
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {
      // FutureBuilder yang menampilkan error; jangan lempar ke framework.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Kode Akses'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: const [SizedBox(height: AppSpacing.lg), AppSkeletonList(count: 6)],
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error is AppError
                ? snapshot.error as AppError
                : AppError.from(snapshot.error!);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppNotice.error(title: error.title, text: error.shortMessage),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ],
            );
          }

          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Belum ada riwayat',
                    subtitle: 'Kode yang pernah diterbitkan, dipakai, atau dicabut akan muncul di sini.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _HistoryCard(row: rows[index]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _HistoryCard({required this.row});

  String get _prefix => row['kode_prefix']?.toString() ?? '—';

  AccessCodeStatus get _status {
    final raw = row['status']?.toString() ?? 'active';
    final expires = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    final revoked = row['revoked_at'] != null;
    final used = row['used_at'] != null;
    if (revoked) return AccessCodeStatus.revoked;
    if (used) return AccessCodeStatus.used;
    if (expires != null && expires.isBefore(DateTime.now())) return AccessCodeStatus.expired;
    return switch (raw) {
      'used' => AccessCodeStatus.used,
      'revoked' => AccessCodeStatus.revoked,
      'expired' => AccessCodeStatus.expired,
      _ => AccessCodeStatus.active,
    };
  }

  (String, Color) get _label => switch (_status) {
        AccessCodeStatus.active => ('Aktif', AppColors.success),
        AccessCodeStatus.used => ('Sudah dipakai', AppColors.info),
        AccessCodeStatus.revoked => ('Dicabut', AppColors.error),
        AccessCodeStatus.expired => ('Kedaluwarsa', AppColors.warning),
      };

  String _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    return DateFormat('d MMM yyyy • HH:mm', 'id_ID').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _label;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Prefix ${_prefix.substring(0, _prefix.length > 8 ? 8 : _prefix.length)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (row['note'] != null && row['note'].toString().isNotEmpty)
                const Icon(Icons.sticky_note_2_outlined, size: 15, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _line(Icons.event_available_rounded, 'Diterbitkan', _date(row['created_at'])),
          if (row['expires_at'] != null)
            _line(Icons.timer_outlined, 'Berlaku sampai', _date(row['expires_at'])),
          if (row['used_at'] != null) _line(Icons.check_circle_outline_rounded, 'Dipakai pada', _date(row['used_at'])),
          if (row['revoked_at'] != null) _line(Icons.block_rounded, 'Dicabut pada', _date(row['revoked_at'])),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
