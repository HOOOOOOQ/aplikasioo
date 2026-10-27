import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../services/connectivity_service.dart';

/// Pita tipis di atas layar yang muncul **hanya** ketika perangkat kehilangan
/// koneksi.
///
/// Tujuan: pengguna tidak bingung ketika sebuah tombol gagal karena jaringan.
/// Pita ini bersifat informasi — tidak menangkap sentuhan (memakai
/// [IgnorePointer]) dan tidak memblokir navigasi, sehingga AppBar serta tombol
/// lain tetap bisa dipakai.
///
/// Status [NetworkStatus.unknown] (plugin tidak tersedia / belum diketahui)
/// tidak menampilkan apa pun supaya tidak ada peringatan palsu.
class AppConnectivityBanner extends ConsumerWidget {
  const AppConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusProvider).valueOrNull;
    if (status != NetworkStatus.offline) return const SizedBox.shrink();

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          color: AppColors.warningDark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 13, color: Colors.white),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Tidak ada koneksi internet — data mungkin belum terbaru',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
