import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_constants.dart';
import '../../core/utils/app_error.dart';
import '../../core/utils/file_utils.dart';
import 'supabase_service.dart';

/// Satu pintu untuk semua operasi lampiran tugas.
///
/// Kontrak path (HARUS sama dengan policy di
/// supabase/migrations/003_storage_attachments.sql):
///   tugas/<guru_id>/<tugas_id>/<uuid>.<ext>
///
/// Bucket bersifat privat. Siswa membaca lampiran lewat signed URL berumur
/// pendek yang dibuat sesuai izin RLS — bukan URL publik permanen.
class AttachmentService {
  AttachmentService._();

  static const String bucket = AppConstants.storageBucketAttachments;
  static const Uuid _uuid = Uuid();

  static const Map<String, String> _mimeByExtension = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    'txt': 'text/plain',
  };

  static String? mimeFor(String fileName) {
    final ext = _extension(fileName);
    return _mimeByExtension[ext];
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// Validasi sisi klien sebelum mengunggah. Server tetap memvalidasi ulang
  /// lewat batas bucket (ukuran + MIME), jadi ini bukan satu-satunya proteksi.
  static String? validate({required String fileName, required int sizeBytes}) {
    if (fileName.trim().isEmpty) return 'Nama file tidak valid.';
    if (!FileUtils.isAllowedExtension(fileName)) {
      return 'Tipe file tidak didukung. Gunakan PDF, DOC/DOCX, PPT/PPTX, '
          'XLS/XLSX, JPG, PNG, atau ZIP.';
    }
    if (sizeBytes <= 0) return 'File kosong atau gagal dibaca.';
    if (FileUtils.isExceedsLimit(sizeBytes)) {
      return 'Ukuran file melebihi ${AppConstants.maxAttachmentSizeMb} MB.';
    }
    return null;
  }

  /// Unggah lampiran untuk tugas milik guru yang sedang login.
  ///
  /// Tugas harus SUDAH tersimpan di database karena policy Storage memeriksa
  /// kepemilikan tugas dari path. Karena itu alur di UI:
  ///   1) simpan tugas → 2) unggah → 3) update kolom lampiran_path.
  static Future<String> uploadForTugas({
    required String tugasId,
    required String guruId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final client = SupabaseService.tryClient;
    if (client == null) {
      throw const AppError(
        title: 'Belum terhubung',
        message: 'Supabase belum siap pada build ini.',
        code: 'config',
      );
    }
    if (tugasId.isEmpty || guruId.isEmpty) {
      throw const AppError(
        title: 'Data tugas tidak lengkap',
        message: 'Tugas harus tersimpan sebelum lampiran diunggah.',
        code: 'missing_ids',
      );
    }

    final validation = validate(fileName: fileName, sizeBytes: bytes.length);
    if (validation != null) {
      throw AppError(title: 'File tidak valid', message: validation, code: 'invalid_file');
    }

    final ext = _extension(fileName);
    final path = 'tugas/$guruId/$tugasId/${_uuid.v4()}.$ext';
    final mime = mimeFor(fileName) ?? 'application/octet-stream';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      return path;
    } on StorageException catch (e) {
      throw AppError.from(e);
    } catch (e) {
      throw AppError.from(e);
    }
  }

  /// Hapus file. Kegagalan tidak dilempar sebagai error keras karena biasanya
  /// hanya dipanggil untuk pembersihan (rollback), tetapi dikembalikan boolean.
  static Future<bool> delete(String path) async {
    if (path.trim().isEmpty) return true;
    final client = SupabaseService.tryClient;
    if (client == null) return false;
    try {
      await client.storage.from(bucket).remove([path]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Signed URL untuk membuka lampiran (bucket privat).
  ///
  /// `expiresInSeconds` default 1 jam. Jika objek tidak ada atau RLS menolak,
  /// mengembalikan null agar UI bisa menampilkan pesan yang jelas.
  static Future<String?> signedUrl(String path, {int expiresInSeconds = 3600}) async {
    if (path.trim().isEmpty) return null;
    final client = SupabaseService.tryClient;
    if (client == null) return null;
    try {
      return await client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
    } catch (_) {
      return null;
    }
  }

  /// Nama file yang ditampilkan ke pengguna dari path penyimpanan.
  static String displayName(String path) {
    final last = path.split('/').last;
    final dot = last.indexOf('.');
    if (dot > 0) return last;
    return last;
  }

  /// Ekstensi file dari path (untuk ikon).
  static String extensionOf(String path) => _extension(path);
}
