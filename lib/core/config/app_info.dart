/// Identitas aplikasi, tim pengembang, dan institusi.
///
/// Semua data di sini berasal dari informasi yang diberikan pemilik proyek.
/// Jangan menambahkan klaim (prestasi, jabatan, afiliasi resmi) yang belum
/// dikonfirmasi. Aplikasi ini BUKAN aplikasi resmi sekolah.
class AppInfo {
  AppInfo._();

  static const String appName = 'EduTask';
  static const String tagline = 'Tugas & Jadwal Sekolah';
  static const String packageName = 'com.edutask.sekolah';
  static const String version = '1.2.0';
  static const String copyright = '© 2026 PALL. All rights reserved.';
  static const String teamMotto = 'From 3 Person To All';

  static const String description =
      'EduTask membantu sekolah mengelola jadwal pelajaran, tugas, lampiran, '
      'dan laporan penyelesaian tugas dalam satu aplikasi.';

  static const List<TeamMember> team = [
    TeamMember(
      name: 'Noval Rizki',
      role: 'Developer',
      instagramHandle: '@pallemnih_',
      instagramUrl: 'https://www.instagram.com/pallemnih_?cplk=MWNud3gxOHBvNTIyZw==',
      icon: 'code',
    ),
    TeamMember(
      name: 'Rohiman',
      role: 'Partner',
      instagramHandle: '@rohim_alfabet',
      instagramUrl: 'https://www.instagram.com/rohim_alfabet?mdxt=MWNndG9jeGY3NDhiZg==',
      icon: 'handshake',
    ),
    TeamMember(
      name: 'Fikri Muhammad Faiz',
      role: 'Penyedia',
      instagramHandle: '@faizzzz.483',
      instagramUrl: 'https://www.instagram.com/faizzzz.483?dlrf=c3RyeXE1ZXh5NHkw',
      icon: 'support',
    ),
  ];

  static const String schoolName = 'SMK Al Madani Garut';
  static const String schoolInstagramHandle = '@smkalmadanigarut';
  static const String schoolInstagramUrl =
      'https://www.instagram.com/smkalmadanigarut?srtk=cTdiZWRjZGsydTd6';

  static const String departmentName = 'PPLG — Pengembangan Perangkat Lunak dan Gim';
  static const String departmentShortName = 'PPLG';
  static const String departmentInstagramHandle = '@pplg.amg';
  static const String departmentInstagramUrl =
      'https://www.instagram.com/pplg.amg?obrf=MWppYWt2MHZ3dml3ZQ==';

  static const String privacyNote =
      'Aplikasi ini dikembangkan untuk kebutuhan pengelolaan tugas sekolah. '
      'Status resmi hanya tercatat setelah identitas siswa terhubung dengan kode akses '
      'yang diterbitkan admin atau guru.';
}

class TeamMember {
  final String name;
  final String role;
  final String instagramHandle;
  final String instagramUrl;
  final String icon;

  const TeamMember({
    required this.name,
    required this.role,
    required this.instagramHandle,
    required this.instagramUrl,
    required this.icon,
  });
}
