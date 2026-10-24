import '../config/app_constants.dart';

class FileUtils {
  static bool isAllowedExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return AppConstants.allowedAttachmentTypes.contains(ext);
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static bool isExceedsLimit(int bytes) {
    return bytes > AppConstants.maxAttachmentSizeMb * 1024 * 1024;
  }
}
