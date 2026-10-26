import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../widgets/confirm_dialog.dart';

/// Apa yang harus dilakukan saat tombol Back Android ditekan.
enum BackActionKind {
  /// Ada halaman yang ditumpuk di atas → pop satu kali.
  popRoute,

  /// Pindah ke rute internal (tab induk / beranda).
  goTo,

  /// Sudah di akar aplikasi → minta konfirmasi sebelum keluar.
  confirmExit,

  /// Sudah di akar dan keluar tanpa konfirmasi (perilaku default OS).
  exitApp,
}

class BackAction {
  final BackActionKind kind;

  /// Rute tujuan (hanya untuk [BackActionKind.goTo]).
  final String? route;

  const BackAction._(this.kind, [this.route]);

  static const BackAction popRoute = BackAction._(BackActionKind.popRoute);
  static const BackAction exitApp = BackAction._(BackActionKind.exitApp);
  static const BackAction confirmExit = BackAction._(BackActionKind.confirmExit);

  factory BackAction.goTo(String route) => BackAction._(BackActionKind.goTo, route);

  @override
  String toString() => 'BackAction(${kind.name}${route == null ? '' : ', $route'})';

  @override
  bool operator ==(Object other) =>
      other is BackAction && other.kind == kind && other.route == route;

  @override
  int get hashCode => Object.hash(kind, route);
}

/// Menentukan satu aksi Back yang benar — tidak pernah dua aksi sekaligus.
///
/// Urutan prioritas:
///  1. halaman yang ditumpuk (`canPop`) → pop,
///  2. sub-halaman di dalam tab (mis. `/admin/tugas/123`) → tab induknya,
///  3. tab selain beranda → beranda,
///  4. akar aplikasi → konfirmasi keluar atau keluar biasa.
///
/// [tabRoutes] diurutkan dari yang paling spesifik; [homeRoute] adalah tab
/// beranda. Fungsi ini murni supaya bisa diuji tanpa widget.
BackAction resolveBackAction({
  required String path,
  required String homeRoute,
  required bool canPop,
  List<String> tabRoutes = const [],
  bool confirmAtRoot = false,
}) {
  if (canPop) return BackAction.popRoute;

  final parent = parentTabFor(path, tabRoutes) ?? homeRoute;
  if (path != parent) return BackAction.goTo(parent);
  return confirmAtRoot ? BackAction.confirmExit : BackAction.exitApp;
}

/// Tab induk untuk [path], mis. `/admin/tugas/123` → `/admin/tugas`.
///
/// Kembalian `null` berarti tidak ada tab induk selain beranda.
String? parentTabFor(String path, List<String> tabRoutes) {
  String? best;
  for (final tab in tabRoutes) {
    if (path == tab) continue;
    if (!path.startsWith('$tab/')) continue;
    if (best == null || tab.length > best.length) best = tab;
  }
  return best;
}

/// Membungkus halaman/shell dengan kebijakan Back yang konsisten.
///
/// * Satu tekan Back = satu aksi.
/// * Dialog & bottom sheet tetap ditutup lebih dulu karena keduanya berada di
///   atas route ini.
/// * Tidak pernah memanggil [SystemNavigator.pop] untuk navigasi biasa; panggilan
///   itu hanya terjadi setelah pengguna **mengonfirmasi** keluar di akar aplikasi.
class AppBackGuard extends StatefulWidget {
  final Widget child;

  /// Rute beranda untuk konteks ini (mis. `/admin`, `/guru`, `/siswa`).
  final String homeRoute;

  /// Daftar tab level atas; dipakai untuk menentukan tab induk sub-halaman.
  final List<String> tabRoutes;

  /// Tampilkan konfirmasi keluar saat benar-benar di akar aplikasi.
  final bool confirmAtRoot;

  final String exitTitle;
  final String exitMessage;

  /// Override untuk pengujian.
  final Future<bool> Function(BuildContext context)? confirmExit;

  /// Aksi keluar. Default: tutup aplikasi lewat [SystemNavigator.pop].
  ///
  /// Pemanggilan ini hanya terjadi di akar aplikasi **setelah** pengguna
  /// menekan tombol keluar pada dialog konfirmasi — bukan untuk navigasi biasa.
  final void Function()? onExit;

  const AppBackGuard({
    super.key,
    required this.child,
    required this.homeRoute,
    this.tabRoutes = const [],
    this.confirmAtRoot = false,
    this.exitTitle = 'Keluar dari EduTask?',
    this.exitMessage = 'Tekan "Keluar" untuk menutup aplikasi.',
    this.confirmExit,
    this.onExit,
  });

  @override
  State<AppBackGuard> createState() => _AppBackGuardState();
}

class _AppBackGuardState extends State<AppBackGuard> {
  /// Waktu aksi Back terakhir. Dipakai sebagai latch 250 ms agar double-tap
  /// tidak memicu dua aksi — tanpa timer yang bisa tertinggal setelah dispose.
  DateTime? _lastActionAt;

  bool get _coolingDown {
    final last = _lastActionAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(milliseconds: 250);
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final action = resolveBackAction(
      path: path,
      homeRoute: widget.homeRoute,
      canPop: GoRouter.of(context).canPop(),
      tabRoutes: widget.tabRoutes,
      confirmAtRoot: widget.confirmAtRoot,
    );

    // Hanya tahan tombol Back bila memang ada aksi internal / konfirmasi.
    // Bila tidak, biarkan sistem menangani (menutup aplikasi) seperti biasa.
    final blockSystem = action.kind == BackActionKind.goTo ||
        action.kind == BackActionKind.confirmExit;

    return PopScope<void>(
      canPop: !blockSystem,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handle(action);
      },
      child: widget.child,
    );
  }

  Future<void> _handle(BackAction action) async {
    if (_coolingDown) return;
    _lastActionAt = DateTime.now();

    final router = GoRouter.of(context);
    switch (action.kind) {
      case BackActionKind.popRoute:
        router.pop();
      case BackActionKind.goTo:
        router.go(action.route!);
      case BackActionKind.exitApp:
        _exit();
      case BackActionKind.confirmExit:
        final confirmed = widget.confirmExit != null
            ? await widget.confirmExit!(context)
            : await showConfirmDialog(
                context,
                title: widget.exitTitle,
                content: widget.exitMessage,
                confirmLabel: 'Keluar',
                cancelLabel: 'Tetap di aplikasi',
              );
        if (!confirmed || !mounted) return;
        _exit();
    }
  }

  void _exit() {
    final handler = widget.onExit;
    if (handler != null) {
      handler();
      return;
    }
    if (kIsWeb) return;
    SystemNavigator.pop();
  }
}

/// Guard ringan untuk halaman tunggal (login, onboarding, halaman siswa)
/// yang tidak memakai shell: Back kembali ke [fallbackRoute] bila halaman ini
/// dibuka lewat `go`, atau pop satu kali bila dibuka lewat `push`.
class SimpleBackGuard extends StatelessWidget {
  final Widget child;
  final String fallbackRoute;
  final bool confirmAtRoot;

  const SimpleBackGuard({
    super.key,
    required this.child,
    required this.fallbackRoute,
    this.confirmAtRoot = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackGuard(
      homeRoute: fallbackRoute,
      confirmAtRoot: confirmAtRoot,
      exitTitle: 'Keluar dari EduTask?',
      exitMessage: 'Anda berada di halaman utama. Tekan "Keluar" untuk menutup aplikasi.',
      child: child,
    );
  }
}

/// Snackbar singkat yang dipakai di beberapa guard (diekspor untuk pengujian).
void showBackNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.textPrimary,
      duration: const Duration(seconds: 2),
    ),
  );
}
