import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

String mapExceptionToMessage(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Network is unreachable')) {
    return 'Tidak ada koneksi internet. Periksa jaringan Anda.';
  }
  if (msg.contains('timeout')) {
    return 'Koneksi timeout. Coba lagi.';
  }
  if (msg.contains('supabase') || msg.contains('Postgrest')) {
    return 'Gagal terhubung ke server. Coba beberapa saat lagi.';
  }
  return msg.replaceAll('Exception: ', '');
}
