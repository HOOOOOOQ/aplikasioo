import 'package:flutter_test/flutter_test.dart';
import 'package:edutask/core/config/app_constants.dart';
import 'package:edutask/core/utils/file_utils.dart';
import 'package:edutask/shared/services/attachment_service.dart';

/// Validasi lampiran berjalan di klien SEBELUM unggah, tetapi server tetap
/// menegakkan batas bucket (ukuran + MIME). Test ini menjaga kontrak keduanya.
void main() {
  group('AttachmentService.validate', () {
    test('menerima PDF dalam batas ukuran', () {
      expect(AttachmentService.validate(fileName: 'tugas.pdf', sizeBytes: 2048), isNull);
    });

    test('menerima DOCX, PPTX, XLSX, JPG, PNG, ZIP', () {
      for (final name in ['a.docx', 'b.pptx', 'c.xlsx', 'd.jpg', 'e.png', 'f.zip']) {
        expect(
          AttachmentService.validate(fileName: name, sizeBytes: 1024),
          isNull,
          reason: '$name seharusnya diterima',
        );
      }
    });

    test('menolak ekstensi berbahaya', () {
      for (final name in ['virus.exe', 'script.sh', 'app.apk', 'noext']) {
        expect(
          AttachmentService.validate(fileName: name, sizeBytes: 1024),
          isNotNull,
          reason: '$name seharusnya ditolak',
        );
      }
    });

    test('menolak file kosong', () {
      expect(AttachmentService.validate(fileName: 'a.pdf', sizeBytes: 0), isNotNull);
    });

    test('menolak file melebihi batas', () {
      const tooBig = AppConstants.maxAttachmentSizeMb * 1024 * 1024 + 1;
      expect(AttachmentService.validate(fileName: 'a.pdf', sizeBytes: tooBig), isNotNull);
    });

    test('menerima tepat pada batas ukuran', () {
      const limit = AppConstants.maxAttachmentSizeMb * 1024 * 1024;
      expect(AttachmentService.validate(fileName: 'a.pdf', sizeBytes: limit), isNull);
    });

    test('ekstensi tidak case-sensitive', () {
      expect(AttachmentService.validate(fileName: 'TUGAS.PDF', sizeBytes: 10), isNull);
    });
  });

  group('MIME map', () {
    test('memetakan tipe yang diizinkan', () {
      expect(AttachmentService.mimeFor('a.pdf'), 'application/pdf');
      expect(AttachmentService.mimeFor('a.docx'),
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(AttachmentService.mimeFor('a.png'), 'image/png');
    });

    test('mengembalikan null untuk tipe tak dikenal', () {
      expect(AttachmentService.mimeFor('a.exe'), isNull);
    });
  });

  group('Utilitas path lampiran', () {
    test('displayName mengambil segmen terakhir', () {
      expect(AttachmentService.displayName('tugas/guru-1/tugas-1/abc.pdf'), 'abc.pdf');
    });

    test('extensionOf mengambil ekstensi', () {
      expect(AttachmentService.extensionOf('tugas/g/t/x.PDF'), 'pdf');
    });
  });

  group('FileUtils', () {
    test('isExceedsLimit konsisten dengan AppConstants', () {
      expect(FileUtils.isExceedsLimit(AppConstants.maxAttachmentSizeMb * 1024 * 1024), isFalse);
      expect(FileUtils.isExceedsLimit(AppConstants.maxAttachmentSizeMb * 1024 * 1024 + 1), isTrue);
    });

    test('isAllowedExtension menolak kosong', () {
      expect(FileUtils.isAllowedExtension(''), isFalse);
    });
  });
}
