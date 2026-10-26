import 'package:edutask/core/services/schema_health.dart';
import 'package:edutask/core/utils/app_error.dart';
import 'package:edutask/shared/repositories/akun_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dashboard harus tetap berguna ketika satu bagian database belum siap, dan
/// menyatakan dengan jujur bagian mana yang gagal (bukan angka 0 palsu).
void main() {
  group('DashboardCounts', () {
    test('tanpa masalah', () {
      const counts = DashboardCounts(
        values: {'guru': 3, 'kelas': 4},
        issues: {},
      );
      expect(counts.hasIssues, isFalse);
      expect(counts.schemaNotReady, isFalse);
      expect(counts['guru'], 3);
      expect(counts.has('kelas'), isTrue);
    });

    test('metrik yang gagal tidak ada di values (UI menampilkan bukan angka)', () {
      const counts = DashboardCounts(
        values: {'guru': 3},
        issues: {
          'kode_aktif': AppError(
            title: 'Skema database belum siap',
            message: 'tabel belum ada',
            code: 'schema_not_ready',
          ),
        },
      );
      expect(counts.hasIssues, isTrue);
      expect(counts.schemaNotReady, isTrue);
      expect(counts.has('kode_aktif'), isFalse);
      expect(counts['kode_aktif'], 0);
    });

    test('error selain skema tetap dilaporkan tanpa dianggap skema', () {
      const counts = DashboardCounts(
        values: {},
        issues: {
          'tugas': AppError(title: 'Akses ditolak', message: 'rls', code: 'rls_denied'),
        },
      );
      expect(counts.hasIssues, isTrue);
      expect(counts.schemaNotReady, isFalse);
    });
  });

  group('SchemaHealth.fromJson', () {
    Map<String, dynamic> healthyJson() => {
          'version': 'edutask-schema-005',
          'tables': {
            'kode_akses_siswa': true,
            'kode_akses_attempt': true,
            'audit_log': true,
            'siswa_akun': true,
          },
          'functions': {
            'claim_kode_akses': true,
            'kode_akses_stats': true,
            'guru_handles_kelas': true,
          },
          'rls_enabled': {
            'kode_akses_siswa': true,
            'audit_log': true,
            'siswa': true,
          },
          'policies': {'kode_akses_siswa': 2, 'audit_log': 1},
          'missing_columns': <String>[],
          'anon_can_select_siswa': false,
        };

    test('skema lengkap dianggap sehat', () {
      final health = SchemaHealth.fromJson(healthyJson());
      expect(health.isHealthy, isTrue);
      expect(health.version, 'edutask-schema-005');
      expect(health.missingTableCount, 0);
      expect(health.issues, isEmpty);
      expect(health.policies['kode_akses_siswa'], 2);
      expect(health.anonCanSelectSiswa, isFalse);
    });

    test('tabel hilang dan kolom kurang dilaporkan sebagai masalah', () {
      final json = healthyJson();
      json['tables'] = {'kode_akses_siswa': false, 'audit_log': true};
      json['missing_columns'] = ['kode_prefix', 'note'];
      final health = SchemaHealth.fromJson(json);
      expect(health.isHealthy, isFalse);
      expect(health.missingTableCount, 1);
      expect(health.issues.any((i) => i.contains('kode_akses_siswa')), isTrue);
      expect(health.issues.any((i) => i.contains('kode_prefix')), isTrue);
    });

    test('RLS yang mati dianggap belum sehat', () {
      final json = healthyJson();
      json['rls_enabled'] = {'kode_akses_siswa': false};
      final health = SchemaHealth.fromJson(json);
      expect(health.isHealthy, isFalse);
      expect(health.issues.any((i) => i.contains('RLS')), isTrue);
    });

    test('payload anon_can_select versi lama tetap dibaca', () {
      final json = healthyJson();
      json.remove('anon_can_select_siswa');
      json['anon_can_select'] = true;
      final health = SchemaHealth.fromJson(json);
      expect(health.anonCanSelectSiswa, isTrue);
    });

    test('payload kosong tidak melempar exception', () {
      final health = SchemaHealth.fromJson(const {});
      expect(health.version, 'tidak diketahui');
      expect(health.tables, isEmpty);
      expect(health.issues, isEmpty);
      // Tidak ada tabel yang dilaporkan → dianggap sehat secara struktural.
      expect(health.isHealthy, isTrue);
    });
  });
}
