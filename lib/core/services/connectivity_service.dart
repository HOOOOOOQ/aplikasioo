import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status konektivitas yang dipakai UI.
///
/// [unknown] dipakai saat plugin tidak tersedia (mis. platform tanpa dukungan)
/// atau hasilnya belum diketahui — UI tidak boleh menampilkan "offline" hanya
/// karena status belum diketahui.
enum NetworkStatus {
  online,
  offline,
  unknown;

  bool get isOffline => this == NetworkStatus.offline;

  /// Terjemahan hasil plugin. Dipisah sebagai fungsi murni supaya bisa diuji
  /// tanpa plugin/emulator.
  ///
  /// Aturan: koneksi dianggap online bila ada minimal satu jalur selain
  /// [ConnectivityResult.none]. Daftar kosong berarti plugin tidak memberi
  /// informasi → [unknown], bukan offline.
  static NetworkStatus fromResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetworkStatus.unknown;
    final hasLink = results.any((r) => r != ConnectivityResult.none);
    return hasLink ? NetworkStatus.online : NetworkStatus.offline;
  }
}

/// Pembungkus tipis `connectivity_plus`.
///
/// Catatan penting: koneksi "ada" tidak menjamin server Supabase terjangkau
/// (Wi-Fi captive portal, DNS gagal, dsb). Karena itu status ini hanya dipakai
/// untuk memberi tahu pengguna lebih awal, **bukan** untuk memblokir operasi —
/// setiap permintaan tetap mencoba dan kegagalan jaringan dilaporkan oleh
/// [AppError].
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Snapshot status saat ini. Kegagalan plugin tidak dilempar ke UI.
  Future<NetworkStatus> check() async {
    try {
      return NetworkStatus.fromResults(await _connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('[Connectivity] check gagal: $error');
      return NetworkStatus.unknown;
    }
  }

  /// Perubahan status. Error plugin diubah menjadi [NetworkStatus.unknown]
  /// agar stream tidak pernah memutus UI dengan exception.
  Stream<NetworkStatus> watch() async* {
    yield await check();
    try {
      yield* _connectivity.onConnectivityChanged.map(NetworkStatus.fromResults);
    } catch (error) {
      debugPrint('[Connectivity] watch gagal: $error');
      yield NetworkStatus.unknown;
    }
  }
}

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

/// Status jaringan yang dipakai `AppConnectivityBanner`.
///
/// Pembuatan plugin dibungkus try/catch: pada platform tanpa implementasi
/// (mis. unit test tanpa mock, atau target yang tidak didukung) status menjadi
/// [NetworkStatus.unknown] sehingga UI tetap berjalan tanpa peringatan palsu.
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  try {
    return ref.watch(connectivityServiceProvider).watch();
  } catch (error) {
    debugPrint('[Connectivity] plugin tidak tersedia: $error');
    return Stream<NetworkStatus>.value(NetworkStatus.unknown);
  }
});
