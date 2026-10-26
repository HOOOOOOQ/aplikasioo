import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../student/identity/student_identity_provider.dart';
import '../domain/akademik_models.dart';
import 'akademik_repository.dart';
import 'student_akademik_gateway.dart';

final akademikRepositoryProvider = Provider<AkademikRepository>((ref) => AkademikRepository());
final penilaianRepositoryProvider = Provider<PenilaianRepository>((ref) => PenilaianRepository());
final komentarRepositoryProvider = Provider<KomentarRepository>((ref) => KomentarRepository());

/// Gateway siswa selalu mengikuti identitas terverifikasi (token HMAC).
final studentGatewayProvider = Provider<StudentAkademikGateway>((ref) {
  final identity = ref.watch(studentIdentityProvider);
  return StudentAkademikGateway(
    token: identity.token,
    siswaId: identity.siswaId,
    siswaNama: identity.siswaNama,
  );
});

final pengumumanProvider =
    FutureProvider.autoDispose.family<List<Pengumuman>, AkademikAudience>((ref, audience) async {
  if (audience == AkademikAudience.staff) {
    return ref.watch(akademikRepositoryProvider).fetchPengumuman();
  }
  return ref.watch(studentGatewayProvider).fetchPengumuman();
});

final kalenderProvider =
    FutureProvider.autoDispose.family<List<KalenderItem>, AkademikAudience>((ref, audience) async {
  if (audience == AkademikAudience.staff) {
    return ref.watch(akademikRepositoryProvider).fetchKalender();
  }
  return ref.watch(studentGatewayProvider).fetchKalender();
});

final notifikasiProvider =
    FutureProvider.autoDispose.family<List<NotifikasiItem>, AkademikAudience>((ref, audience) async {
  if (audience == AkademikAudience.staff) {
    return ref.watch(akademikRepositoryProvider).fetchNotifikasi();
  }
  return ref.watch(studentGatewayProvider).fetchNotifikasi();
});

final chatThreadsProvider =
    FutureProvider.autoDispose.family<List<ChatThread>, AkademikAudience>((ref, audience) async {
  if (audience == AkademikAudience.staff) {
    return ref.watch(akademikRepositoryProvider).fetchThreads();
  }
  return ref.watch(studentGatewayProvider).fetchThreads();
});

final akademikStatsProvider = FutureProvider.autoDispose<AkademikStats>((ref) async {
  return ref.watch(akademikRepositoryProvider).fetchStats();
});

typedef SearchArgs = ({AkademikAudience audience, String query, String? kelasId});

final pencarianProvider =
    FutureProvider.autoDispose.family<List<SearchHit>, SearchArgs>((ref, args) async {
  final q = args.query.trim();
  if (q.length < 2) return const [];
  if (args.audience == AkademikAudience.staff) {
    return ref.watch(akademikRepositoryProvider).search(q);
  }
  return ref.watch(studentGatewayProvider).search(q, kelasId: args.kelasId);
});

/// Jumlah notifikasi belum dibaca (badge pada menu).
final unreadNotifikasiCountProvider =
    Provider.autoDispose.family<int, AkademikAudience>((ref, audience) {
  final async = ref.watch(notifikasiProvider(audience));
  return async.maybeWhen(
    data: (items) => items.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Pengumpulan jawaban siswa untuk satu tugas (sisi siswa).
final mySubmissionsProvider =
    FutureProvider.autoDispose.family<List<Pengumpulan>, String>((ref, tugasId) async {
  final gateway = ref.watch(studentGatewayProvider);
  if (!gateway.hasIdentity) return const [];
  return gateway.mySubmissions(tugasId: tugasId);
});

/// Pengumpulan seluruh siswa pada satu tugas (sisi guru/admin).
final tugasPengumpulanProvider =
    FutureProvider.autoDispose.family<List<Pengumpulan>, String>((ref, tugasId) async {
  return ref.watch(penilaianRepositoryProvider).fetchPengumpulan(tugasId);
});

/// Komentar diskusi tugas.
final komentarTugasProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({String tugasId, bool staff})>(
        (ref, args) async {
  if (args.staff) {
    return ref.watch(komentarRepositoryProvider).fetch(tugasId: args.tugasId);
  }
  return ref.watch(studentGatewayProvider).listComments(args.tugasId);
});

/// Rekap nilai siswa untuk ringkasan di beranda.
final ringkasanNilaiProvider = FutureProvider.autoDispose<List<Pengumpulan>>((ref) async {
  final gateway = ref.watch(studentGatewayProvider);
  if (!gateway.hasIdentity) return const [];
  return gateway.mySubmissions();
});
