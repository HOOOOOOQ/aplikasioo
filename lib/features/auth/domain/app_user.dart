import 'package:equatable/equatable.dart';

enum UserRole { admin, guru, unknown }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.guru:
        return 'Guru';
      case UserRole.unknown:
        return 'Tidak dikenal';
    }
  }

  static UserRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'guru':
        return UserRole.guru;
      default:
        return UserRole.unknown;
    }
  }
}

class AppUser extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime safeParse(dynamic v) {
      if (v == null) return DateTime.now();
      try { return DateTime.parse(v as String); } catch (_) { return DateTime.now(); }
    }
    return AppUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Tanpa Nama',
      role: UserRoleX.fromString(json['role'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: safeParse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role.name,
        'is_active': isActive,
      };

  bool get isAdmin => role == UserRole.admin;
  bool get isGuru => role == UserRole.guru;

  @override
  List<Object?> get props => [id, email, role, isActive];
}
