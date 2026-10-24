import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/core/utils/deadline_helper.dart';

void main() {
  group('DeadlineHelper edge cases', () {
    test('deadline null -> normal', () {
      final s = DeadlineHelper.getStatus(deadline: null, isCompleted: false);
      expect(s, DeadlineStatus.normal);
    });

    test('deadline selesai prioritas', () {
      final past = DateTime.now().subtract(const Duration(days: 10));
      expect(DeadlineHelper.getStatus(deadline: past, isCompleted: true), DeadlineStatus.selesai);
    });

    test('colorForStatus returns color', () {
      expect(DeadlineHelper.colorForStatus(DeadlineStatus.selesai), isNotNull);
      expect(DeadlineHelper.colorForStatus(DeadlineStatus.terlambat), isNotNull);
      expect(DeadlineHelper.colorForStatus(DeadlineStatus.mendekatiTenggat), isNotNull);
      expect(DeadlineHelper.colorForStatus(DeadlineStatus.normal), isNotNull);
    });

    test('labelForStatus', () {
      expect(DeadlineHelper.labelForStatus(DeadlineStatus.selesai), 'Selesai');
      expect(DeadlineHelper.labelForStatus(DeadlineStatus.terlambat), 'Terlambat');
      expect(DeadlineHelper.labelForStatus(DeadlineStatus.mendekatiTenggat), 'Mendekati Tenggat');
    });

    test('deadline 23h -> mendekati', () {
      final d = DateTime.now().add(const Duration(hours: 23));
      expect(DeadlineHelper.getStatus(deadline: d, isCompleted: false), DeadlineStatus.mendekatiTenggat);
    });

    test('deadline 25h -> normal', () {
      final d = DateTime.now().add(const Duration(hours: 25));
      expect(DeadlineHelper.getStatus(deadline: d, isCompleted: false), DeadlineStatus.normal);
    });
  });
}
