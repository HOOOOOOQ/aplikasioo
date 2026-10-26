import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../core/widgets/app_banner.dart';

class _OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> highlights;

  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.highlights,
  });
}

const List<_OnboardingStep> _steps = [
  _OnboardingStep(
    title: 'Kenali EduTask',
    description:
        'EduTask membantu mengelola tugas, jadwal sekolah, pengumuman, dan komunikasi '
        'pembelajaran dalam satu aplikasi.',
    icon: Icons.school_rounded,
    color: AppColors.primary,
    highlights: ['Jadwal & tugas terpusat', 'Untuk admin, guru, dan siswa'],
  ),
  _OnboardingStep(
    title: 'Masuk sebagai Guru atau Admin',
    description:
        'Guru dan admin masuk dengan akun yang diberikan pengelola sekolah. Menu dan '
        'data yang tampil selalu mengikuti peran akun tersebut.',
    icon: Icons.login_rounded,
    color: AppColors.info,
    highlights: ['Guru mengelola tugas & jadwal kelasnya', 'Admin mengelola data sekolah'],
  ),
  _OnboardingStep(
    title: 'Siswa: Tugas & Jadwal',
    description:
        'Siswa dapat melihat jadwal pelajaran dan daftar tugas tanpa login. '
        'Tenggat waktu dan instruksi tampil langsung di beranda.',
    icon: Icons.assignment_turned_in_rounded,
    color: AppColors.success,
    highlights: ['Filter tugas & tenggat', 'Jadwal mingguan per kelas'],
  ),
  _OnboardingStep(
    title: 'Hubungkan Identitas via Kode Akses',
    description:
        'Kode akses diberikan guru atau admin. Setelah dihubungkan, siswa dapat mengirim '
        'jawaban tugas, melihat nilai, dan mengikuti diskusi kelas.',
    icon: Icons.verified_user_rounded,
    color: AppColors.warning,
    highlights: ['Kode sekali pakai dari guru', 'Tidak perlu password siswa'],
  ),
  _OnboardingStep(
    title: 'Notifikasi, Chat, dan Pengumpulan',
    description:
        'Pantau pengumuman, kirim pesan ke guru atau grup kelas, dan kumpulkan tugas '
        'tepat waktu. Semua pemberitahuan tersimpan di pusat notifikasi.',
    icon: Icons.forum_rounded,
    color: AppColors.primary,
    highlights: ['Chat privat & grup kelas', 'Nilai dan umpan balik guru'],
  ),
];

class OnboardingPage extends StatefulWidget {
  final bool showSkip;

  const OnboardingPage({super.key, this.showSkip = true});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _steps.length - 1;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await OnboardingService.markCompleted();
    if (!mounted) return;

    // Jika dibuka dari halaman login (push), kembali ke sana tanpa mengubah sesi.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Row(
                children: [
                  const EduTaskLogo(size: 34, withShadow: false),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'EduTask',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  if (widget.showSkip && !_isLast)
                    TextButton(
                      onPressed: _finishing ? null : _finish,
                      child: const Text('Lewati'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  return _StepView(step: _steps[index]);
                },
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey(step.title),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 7,
                        width: active ? 22 : 7,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Langkah ${_index + 1} dari ${_steps.length}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
              child: Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _finishing ? null : _previous,
                        child: const Text('Kembali'),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: _index > 0 ? 1 : 2,
                    child: FilledButton(
                      onPressed: _finishing ? null : _next,
                      child: _finishing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isLast ? 'Mulai Sekarang' : 'Lanjut'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final _OnboardingStep step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          TweenAnimationBuilder<double>(
            key: ValueKey(step.title),
            tween: Tween(begin: 0.86, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    step.color.withValues(alpha: 0.16),
                    step.color.withValues(alpha: 0.04),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: step.color,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: step.color.withValues(alpha: 0.3),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(step.icon, size: 46, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...step.highlights.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: step.color),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
