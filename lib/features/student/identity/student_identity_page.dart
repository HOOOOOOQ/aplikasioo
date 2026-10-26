import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/siswa.dart';
import '../../../shared/repositories/siswa_repository.dart';
import 'student_identity_provider.dart';

final kelasRosterProvider = FutureProvider.family<List<Siswa>, String>((ref, kelasId) {
  return SiswaRepository().fetchByKelas(kelasId);
});

class StudentIdentityPage extends ConsumerStatefulWidget {
  const StudentIdentityPage({super.key});

  @override
  ConsumerState<StudentIdentityPage> createState() => _StudentIdentityPageState();
}

class _StudentIdentityPageState extends ConsumerState<StudentIdentityPage> {
  final TextEditingController _codeC = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  bool _verifying = false;
  bool _binding = false;
  AppError? _error;

  // Langkah 2 untuk kode kelas
  String? _claimToken;
  String? _claimKelasId;
  String? _claimKelasNama;
  String? _selectedSiswaId;

  @override
  void dispose() {
    _codeC.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _resetClassStep() {
    setState(() {
      _claimToken = null;
      _claimKelasId = null;
      _claimKelasNama = null;
      _selectedSiswaId = null;
    });
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });

    final result = await ref.read(studentIdentityProvider.notifier).verifyCode(_codeC.text);

    if (!mounted) return;
    setState(() => _verifying = false);

    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }

    if (result.needsClassSelection) {
      if (result.claimToken == null || result.kelasId == null) {
        setState(() => _error = const AppError(
              title: 'Kode kelas tidak lengkap',
              message: 'Server tidak mengirim data kelas untuk kode ini.',
              code: 'bad_response',
            ));
        return;
      }
      setState(() {
        _claimToken = result.claimToken;
        _claimKelasId = result.kelasId;
        _claimKelasNama = result.kelasNama;
        _selectedSiswaId = null;
      });
      return;
    }

    _codeC.clear();
    if (!mounted) return;
    showAppSnackBar(context, 'Identitas berhasil terhubung. Status tugas kini tercatat resmi.');
  }

  Future<void> _bind() async {
    final siswaId = _selectedSiswaId;
    final claimToken = _claimToken;
    if (siswaId == null || claimToken == null) {
      showAppSnackBar(context, 'Pilih nama Anda terlebih dahulu.', isError: true);
      return;
    }

    final roster = ref.read(kelasRosterProvider(_claimKelasId ?? '')).valueOrNull ?? const <Siswa>[];
    final siswa = roster.where((s) => s.id == siswaId).toList();

    setState(() {
      _binding = true;
      _error = null;
    });

    final result = await ref.read(studentIdentityProvider.notifier).bindClassIdentity(
          claimToken: claimToken,
          siswaId: siswaId,
          siswaNama: siswa.isNotEmpty ? siswa.first.nama : '',
          kelasId: _claimKelasId,
          kelasNama: _claimKelasNama,
        );

    if (!mounted) return;
    setState(() => _binding = false);

    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }

    _resetClassStep();
    _codeC.clear();
    if (!mounted) return;
    showAppSnackBar(context, 'Identitas berhasil terhubung.');
  }

  Future<void> _removeIdentity() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus identitas?',
      content: 'Status tugas yang sudah tercatat resmi di server tetap tersimpan. '
          'Setelah dihapus, perubahan status berikutnya hanya tersimpan di perangkat ini.',
      confirmLabel: 'Hapus',
    );
    if (!confirmed) return;
    await ref.read(studentIdentityProvider.notifier).clear();
    if (!mounted) return;
    showAppSnackBar(context, 'Identitas dihapus dari perangkat ini.');
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(studentIdentityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identitas Siswa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/siswa'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          if (identity.isIdentified) _verifiedCard(identity) else _unverifiedCard(),
          const SizedBox(height: AppSpacing.lg),
          _explanationCard(),
          const SizedBox(height: AppSpacing.lg),
          if (!identity.isIdentified) ...[
            if (_claimToken != null && _claimKelasId != null)
              _classSelectionCard()
            else
              _codeFormCard(),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppNotice.error(
                title: _error!.title,
                text: _error!.hint == null ? _error!.message : '${_error!.message}\n${_error!.hint}',
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          _localVsOfficialCard(identity.isIdentified),
        ],
      ),
    );
  }

  Widget _verifiedCard(StudentIdentity identity) {
    final verifiedAt = identity.verifiedAt;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: AppColors.successGradient,
      border: Border.all(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identitas terhubung',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      'Status tugas yang kamu ubah akan tercatat resmi ke guru.',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            identity.siswaNama ?? 'Siswa',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
          ),
          const SizedBox(height: 2),
          Text(
            identity.kelasNama ?? identity.kelasId ?? 'Kelas belum diatur',
            style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.92)),
          ),
          if (verifiedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Diverifikasi ${verifiedAt.day}/${verifiedAt.month}/${verifiedAt.year}',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _removeIdentity,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                  ),
                  icon: const Icon(Icons.link_off_rounded, size: 17),
                  label: const Text('Hapus identitas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unverifiedCard() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: AppColors.primaryGradient,
      border: Border.all(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.badge_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Belum terhubung',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const StatusSourceBadgeInline(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Masukkan kode akses dari admin atau guru untuk menghubungkan identitasmu. '
            'Tanpa kode, kamu tetap bisa melihat jadwal dan tugas.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.white.withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }

  Widget _explanationCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Text('Apa itu kode akses?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Kode akses dibuat oleh admin atau guru dan hanya berlaku untuk siswa/kelas yang dituju. '
            'Verifikasi dilakukan di server, jadi kode tidak bisa dipalsukan dari aplikasi.',
            style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          const _Bullet(
            icon: Icons.security_rounded,
            text: 'Kode disimpan dalam bentuk hash dan tidak ditampilkan lagi setelah dibuat.',
          ),
          const _Bullet(
            icon: Icons.timer_outlined,
            text: 'Kode bisa memiliki masa berlaku dan batas sekali pakai.',
          ),
          const _Bullet(
            icon: Icons.person_search_rounded,
            text: 'Kode kelas meminta kamu memilih nama sendiri agar identitas sesuai.',
          ),
        ],
      ),
    );
  }

  Widget _codeFormCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Masukkan kode akses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Format umum: EDT-XXXXX-XXXXX',
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _codeC,
            focusNode: _codeFocus,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifying ? null : _verify(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
              LengthLimitingTextInputFormatter(24),
            ],
            decoration: const InputDecoration(
              labelText: 'Kode akses',
              hintText: 'Ketik kode dari guru',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _verifying ? null : _verify,
              icon: _verifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_rounded, size: 18),
              label: Text(_verifying ? 'Memverifikasi…' : 'Verifikasi ke server'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Kode tidak disimpan di perangkat. Jangan bagikan kode ke siswa lain.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _classSelectionCard() {
    final rosterAsync = ref.watch(kelasRosterProvider(_claimKelasId!));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Pilih namamu — ${_claimKelasNama ?? 'kelas'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Kode ini berlaku untuk satu kelas. Pilih nama yang benar agar status tugas tercatat pada siswa yang tepat.',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          rosterAsync.when(
            loading: () => const AppLoading(message: 'Memuat daftar siswa…', compact: true),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.invalidate(kelasRosterProvider(_claimKelasId!)),
            ),
            data: (roster) {
              if (roster.isEmpty) {
                return const AppNotice.warning(
                  text: 'Belum ada siswa aktif di kelas ini. Hubungi admin.',
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: roster.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final siswa = roster[index];
                    final selected = _selectedSiswaId == siswa.id;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => setState(() => _selectedSiswaId = siswa.id),
                      leading: Radio<String>(
                        value: siswa.id,
                        groupValue: _selectedSiswaId,
                        onChanged: (value) => setState(() => _selectedSiswaId = value),
                      ),
                      title: Text(siswa.nama, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text('NIS ${siswa.nomorInduk}', style: const TextStyle(fontSize: 11.5)),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                          : null,
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              TextButton(
                onPressed: _binding ? null : _resetClassStep,
                child: const Text('Batal'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _binding || _selectedSiswaId == null ? null : _bind,
                  icon: _binding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link_rounded, size: 18),
                  label: Text(_binding ? 'Menghubungkan…' : 'Hubungkan identitas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _localVsOfficialCard(bool official) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status lokal vs status resmi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(
            icon: Icons.phone_android_rounded,
            color: AppColors.textSecondary,
            title: 'Lokal (perangkat)',
            description: 'Tanpa kode akses. Bisa melihat jadwal & tugas, tetapi tanda selesai '
                'hanya tersimpan di HP ini dan tidak terlihat guru.',
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusRow(
            icon: Icons.cloud_done_rounded,
            color: AppColors.success,
            title: 'Resmi (server)',
            description: 'Setelah identitas terhubung. Perubahan status dikirim ke server dan '
                'masuk laporan guru/admin.',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusSourceBadge(official: official, compact: true),
              const SizedBox(width: AppSpacing.sm),
              Text(
                official ? 'Identitasmu saat ini terhubung.' : 'Saat ini kamu memakai status lokal.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge ringkas untuk kartu gradien (teks putih).
class StatusSourceBadgeInline extends StatelessWidget {
  const StatusSourceBadgeInline({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Status lokal',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
