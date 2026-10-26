import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum AccessCodeStatus { active, used, revoked, expired }

extension AccessCodeStatusX on AccessCodeStatus {
  String get label {
    switch (this) {
      case AccessCodeStatus.active:
        return 'Aktif';
      case AccessCodeStatus.used:
        return 'Sudah dipakai';
      case AccessCodeStatus.revoked:
        return 'Dicabut';
      case AccessCodeStatus.expired:
        return 'Kedaluwarsa';
    }
  }

  Color get color {
    switch (this) {
      case AccessCodeStatus.active:
        return AppColors.success;
      case AccessCodeStatus.used:
        return AppColors.info;
      case AccessCodeStatus.revoked:
        return AppColors.error;
      case AccessCodeStatus.expired:
        return AppColors.textSecondary;
    }
  }

  IconData get icon {
    switch (this) {
      case AccessCodeStatus.active:
        return Icons.check_circle_rounded;
      case AccessCodeStatus.used:
        return Icons.task_alt_rounded;
      case AccessCodeStatus.revoked:
        return Icons.block_rounded;
      case AccessCodeStatus.expired:
        return Icons.schedule_rounded;
    }
  }

  static AccessCodeStatus fromDb(String? raw) {
    switch (raw) {
      case 'used':
        return AccessCodeStatus.used;
      case 'revoked':
        return AccessCodeStatus.revoked;
      case 'expired':
        return AccessCodeStatus.expired;
      default:
        return AccessCodeStatus.active;
    }
  }
}

/// Satu baris `public.kode_akses_siswa`.
///
/// Server tidak menyimpan plaintext kode — hanya hash dan prefix untuk
/// ditampilkan ("EDT-AB…"). Kode lengkap hanya muncul sekali saat dibuat.
class AccessCode {
  final String id;
  final String prefix;
  final String kelasId;
  final String? kelasNama;
  final String? siswaId;
  final String? siswaNama;
  final bool singleUse;
  final AccessCodeStatus dbStatus;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String? usedBySiswaId;
  final String? usedByNama;
  final DateTime createdAt;
  final String? createdByNama;
  final String? note;

  const AccessCode({
    required this.id,
    required this.prefix,
    required this.kelasId,
    this.kelasNama,
    this.siswaId,
    this.siswaNama,
    required this.singleUse,
    required this.dbStatus,
    this.expiresAt,
    this.usedAt,
    this.usedBySiswaId,
    this.usedByNama,
    required this.createdAt,
    this.createdByNama,
    this.note,
  });

  /// Status efektif: kode "active" yang sudah lewat masa berlaku dianggap
  /// kedaluwarsa walau server belum sempat menandainya.
  AccessCodeStatus get status {
    if (dbStatus == AccessCodeStatus.active &&
        expiresAt != null &&
        !expiresAt!.isAfter(DateTime.now())) {
      return AccessCodeStatus.expired;
    }
    return dbStatus;
  }

  bool get isActive => status == AccessCodeStatus.active;

  bool get isSingleUse => singleUse;

  String get targetLabel {
    if (siswaNama != null && siswaNama!.isNotEmpty) return siswaNama!;
    return kelasNama ?? 'Kelas';
  }

  factory AccessCode.fromRow(
    Map<String, dynamic> row, {
    String? kelasNama,
    String? siswaNama,
    String? usedByNama,
    String? createdByNama,
  }) {
    DateTime? parse(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return AccessCode(
      id: row['id'] as String? ?? '',
      prefix: row['kode_prefix'] as String? ?? 'EDT-???',
      kelasId: row['kelas_id'] as String? ?? '',
      kelasNama: kelasNama,
      siswaId: row['siswa_id'] as String?,
      siswaNama: siswaNama,
      singleUse: row['single_use'] as bool? ?? true,
      dbStatus: AccessCodeStatusX.fromDb(row['status'] as String?),
      expiresAt: parse(row['expires_at']),
      usedAt: parse(row['used_at']),
      usedBySiswaId: row['used_by_siswa_id'] as String?,
      usedByNama: usedByNama,
      createdAt: parse(row['created_at']) ?? DateTime.now(),
      createdByNama: createdByNama,
      note: row['note'] as String?,
    );
  }
}

/// Hasil penerbitan kode (plaintext hanya ada di sini, sekali).
class IssuedAccessCode {
  final String code;
  final String id;
  final DateTime? expiresAt;

  const IssuedAccessCode({required this.code, required this.id, this.expiresAt});
}

/// Statistik kode akses.
///
/// Sumber utama: RPC `kode_akses_stats()` (dihitung di database, mengikuti RLS).
/// Sumber cadangan: [AccessCodeStats.fromList] saat RPC belum tersedia
/// (migration belum dijalankan) — UI wajib menandai bahwa angkanya perkiraan.
class AccessCodeStats {
  final int total;
  final int active;
  final int used;
  final int expired;
  final int revoked;

  /// True bila angka dihitung dari daftar yang dimuat di klien, bukan dari DB.
  final bool approximate;

  const AccessCodeStats({
    required this.total,
    required this.active,
    required this.used,
    required this.expired,
    required this.revoked,
    this.approximate = false,
  });

  static const AccessCodeStats empty = AccessCodeStats(
    total: 0,
    active: 0,
    used: 0,
    expired: 0,
    revoked: 0,
  );

  factory AccessCodeStats.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return AccessCodeStats(
      total: read('total'),
      active: read('active'),
      used: read('used'),
      expired: read('expired'),
      revoked: read('revoked'),
    );
  }

  /// Hitung dari daftar yang sudah dimuat (cadangan).
  factory AccessCodeStats.fromList(List<AccessCode> codes) {
    final counts = <AccessCodeStatus, int>{};
    for (final code in codes) {
      final status = code.status;
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return AccessCodeStats(
      total: codes.length,
      active: counts[AccessCodeStatus.active] ?? 0,
      used: counts[AccessCodeStatus.used] ?? 0,
      expired: counts[AccessCodeStatus.expired] ?? 0,
      revoked: counts[AccessCodeStatus.revoked] ?? 0,
      approximate: true,
    );
  }
}
