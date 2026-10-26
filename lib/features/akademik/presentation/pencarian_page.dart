import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../student/identity/student_identity_provider.dart';
import '../data/akademik_providers.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';

/// Pencarian global.
///
/// Staff memakai RPC `edutask_search` (tugas, kelas, guru, pengumuman) yang
/// berjalan dengan hak akses pengguna, sehingga RLS tetap berlaku. Siswa
/// mencari pada data publik yang boleh dibacanya (pengumuman, kalender, tugas
/// kelasnya).
class PencarianPage extends ConsumerStatefulWidget {
  final AkademikAudience audience;

  const PencarianPage({super.key, required this.audience});

  @override
  ConsumerState<PencarianPage> createState() => _PencarianPageState();
}

class _PencarianPageState extends ConsumerState<PencarianPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  String _routeFor(SearchHit hit) {
    if (widget.audience == AkademikAudience.siswa) {
      return hit.route.startsWith('/siswa') ? hit.route : '/siswa';
    }
    if (hit.route.startsWith('/admin') || hit.route.startsWith('/guru')) {
      final path = GoRouterState.of(context).uri.path;
      if (path.startsWith('/admin') && hit.route.startsWith('/guru')) {
        // Admin boleh membuka detail tugas lewat rute admin.
        return hit.route.replaceFirst('/guru', '/admin');
      }
      return hit.route;
    }
    return '/admin';
  }

  @override
  Widget build(BuildContext context) {
    final kelasId = ref.watch(studentIdentityProvider).kelasId;
    final args = (audience: widget.audience, query: _query, kelasId: kelasId);
    final async = _query.length < 2 ? null : ref.watch(pencarianProvider(args));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.audience == AkademikAudience.siswa
                ? 'Cari tugas, pengumuman, agenda…'
                : 'Cari tugas, kelas, guru, pengumuman…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Hapus',
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: async == null
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: const [
                SizedBox(height: 40),
                EmptyState(
                  icon: Icons.search_rounded,
                  title: 'Mulai mencari',
                  subtitle: 'Ketik minimal 2 karakter untuk mencari di seluruh data akademik.',
                ),
              ],
            )
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AkademikErrorView(
                error: e,
                onRetry: () => ref.invalidate(pencarianProvider(args)),
              ),
              data: (hits) {
                if (hits.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      const SizedBox(height: 40),
                      EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Tidak ada hasil',
                        subtitle: 'Tidak ada data yang cocok dengan "$_query". Coba kata kunci lain.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                  itemCount: hits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final hit = hits[index];
                    return AppCard(
                      onTap: () => context.push(_routeFor(hit)),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: AppColors.primaryContainer,
                            child: Icon(_iconFor(hit.tipe), size: 17, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hit.judul,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  hit.subjudul,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  IconData _iconFor(String tipe) => switch (tipe) {
        'tugas' => Icons.assignment_rounded,
        'kelas' => Icons.class_rounded,
        'guru' => Icons.badge_rounded,
        'pengumuman' => Icons.campaign_rounded,
        'kalender' => Icons.event_rounded,
        _ => Icons.search_rounded,
      };
}
