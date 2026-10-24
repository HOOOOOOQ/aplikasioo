class AppConstants {
  static const String appName = 'EduTask';
  static const String appTagline = 'Tugas & Jadwal Sekolah';
  static const String packageName = 'com.edutask.sekolah';

  // Pagination
  static const int pageSize = 20;
  static const int searchDebounceMs = 400;

  // Supabase
  static const String storageBucketAttachments = 'lampiran-tugas';
  static const int maxAttachmentSizeMb = 10;
  static const List<String> allowedAttachmentTypes = [
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
    'jpg',
    'jpeg',
    'png',
    'zip',
    'rar',
  ];

  // Student identity
  static const String spStudentIdKey = 'student_identity_id';
  static const String spStudentCodeKey = 'student_identity_code';
  static const String spStudentTokenKey = 'student_access_token';
  static const String spSelectedKelasId = 'selected_kelas_id';
  static const String spThemeMode = 'theme_mode';

  // Date formats
  static const String dateFormatDisplay = 'dd MMMM yyyy';
  static const String dateFormatShort = 'dd/MM/yyyy';
  static const String timeFormatDisplay = 'HH:mm';

  // Deadline thresholds
  static const int deadlineWarningHours = 24;

  // Timezone
  static const String timezoneJakarta = 'Asia/Jakarta';
}
