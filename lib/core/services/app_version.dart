import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_info.dart';
import '../constants/app_colors.dart';

/// Versi & nomor build yang **sebenarnya** terpasang di perangkat.
///
/// Dibaca dari metadata aplikasi (Android `versionName`/`versionCode`) sehingga
/// tidak pernah berbeda dengan APK yang diinstal. Bila plugin tidak tersedia
/// (mis. pada widget test), nilai cadangan dari [AppInfo] dipakai.
class AppVersion {
  final String version;
  final String build;
  final bool fromDevice;

  const AppVersion({required this.version, required this.build, this.fromDevice = false});

  static const AppVersion fallback = AppVersion(version: AppInfo.version, build: '-');

  String get label => build == '-' || build.isEmpty ? 'v$version' : 'v$version ($build)';
}

final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.isEmpty ? AppInfo.version : info.version;
    final build = info.buildNumber.isEmpty ? '-' : info.buildNumber;
    return AppVersion(version: version, build: build, fromDevice: true);
  } catch (_) {
    // Plugin tidak tersedia atau gagal membaca metadata: jangan gagalkan UI.
    return AppVersion.fallback;
  }
});

/// Label versi kecil yang dipakai di splash, Tentang, dan pengaturan.
class AppVersionLabel extends ConsumerWidget {
  final Color? color;
  final double fontSize;
  final String suffix;

  const AppVersionLabel({
    super.key,
    this.color,
    this.fontSize = 11,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appVersionProvider);
    final version = async.valueOrNull ?? AppVersion.fallback;
    final versionText = async.isLoading && !version.fromDevice ? 'v${AppInfo.version}' : version.label;
    return Text(
      suffix.isEmpty ? versionText : '$versionText • $suffix',
      style: TextStyle(fontSize: fontSize, color: color ?? AppColors.textTertiary),
    );
  }
}
