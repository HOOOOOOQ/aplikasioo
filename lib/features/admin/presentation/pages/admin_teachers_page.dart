import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/auth_provider.dart';

class AdminTeachersPage extends ConsumerStatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  ConsumerState<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends ConsumerState<AdminTeachersPage> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _inviting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseConfig.isNotConfigured) {
      setState(() { _loading = false; _error = 'Supabase belum dikonfigurasi'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final c = SupabaseService.tryClient;
      if (c == null) throw Exception('Supabase belum siap');
      final data = await c.from('profiles').select().eq('role', 'guru').order('full_name');
      if (!mounted) return;
      setState(() { _list = (data as List).cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _showInvite() async {
    final emailC = TextEditingController();
    final nameC = TextEditingController();
    final passC = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undang / Tambah Guru'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama Lengkap *'), validator: (v) => Validators.requiredField(v, fieldName: 'Nama')),
                const SizedBox(height: 12),
                TextFormField(controller: emailC, decoration: const InputDecoration(labelText: 'Email *'), validator: Validators.email),
                const SizedBox(height: 12),
                TextFormField(controller: passC, decoration: const InputDecoration(labelText: 'Password Sementara *'), validator: Validators.password, obscureText: true),
                const SizedBox(height: 8),
                const Text('Akun akan dibuat via Edge Function aman (service_role di server). Jika belum deploy, hubungi admin untuk membuat via Supabase Dashboard.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () { if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true); }, child: const Text('Undang')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    // Tampilkan status proses pada FAB (tanpa dialog loading yang bisa salah pop).
    setState(() => _inviting = true);
    try {
      await ref.read(authRepositoryProvider).createTeacherAccount(
        email: emailC.text.trim(),
        password: passC.text,
        fullName: nameC.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Guru berhasil diundang: ${emailC.text.trim()}');
      await _load();
    } on TeacherInviteException catch (e) {
      if (!mounted) return;
      // Tampilkan penyebab lengkap (SnackBar memotong teks panjang).
      final relogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_inviteErrorTitle(e)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.message),
                if (e.status != null) ...[
                  const SizedBox(height: 8),
                  Text('HTTP status: ${e.status}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
            if (e.requiresRelogin || e.status == 401)
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Login Ulang')),
          ],
        ),
      );
      if (relogin == true && mounted) {
        // Satu kali login ulang, tidak ada retry otomatis tanpa batas.
        await ref.read(authControllerProvider.notifier).signOut();
        if (mounted) context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  String _inviteErrorTitle(TeacherInviteException e) {
    switch (e.code) {
      case 'session_expired':
        return 'Sesi Admin Berakhir';
      case 'unauthorized':
        return 'Ditolak Server (401)';
      case 'forbidden':
        return 'Akses Ditolak (403)';
      case 'not_deployed':
        return 'Edge Function Belum Dideploy';
      case 'network':
        return 'Koneksi Bermasalah';
      case 'invalid_input':
        return 'Data Tidak Valid';
      case 'config':
        return 'Supabase Belum Dikonfigurasi';
      default:
        return 'Gagal Mengundang Guru';
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> guru) async {
    final current = guru['is_active'] as bool? ?? true;
    try {
      final c = SupabaseService.tryClient;
      if (c == null) throw Exception('Supabase belum siap');
      await c.from('profiles').update({'is_active': !current}).eq('id', guru['id']);
      if (mounted) showAppSnackBar(context, current ? 'Guru dinonaktifkan' : 'Guru diaktifkan');
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Gagal: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Data Guru'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _inviting ? null : _showInvite,
        icon: _inviting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.person_add),
        label: Text(_inviting ? 'Memproses...' : 'Undang Guru'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _list.isEmpty
                  ? const EmptyState(icon: Icons.badge, title: 'Belum Ada Guru', subtitle: 'Undang guru dengan email untuk memberikan akses kelola tugas.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _list.length,
                      itemBuilder: (ctx, i) {
                        final g = _list[i];
                        final active = g['is_active'] as bool? ?? true;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: active ? AppColors.successContainer : AppColors.errorContainer, child: Icon(Icons.badge, color: active ? AppColors.success : AppColors.error)),
                            title: Text(g['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${g['email'] ?? '-'} \nStatus: ${active ? "Aktif" : "Nonaktif"}', style: const TextStyle(fontSize: 12)),
                            isThreeLine: true,
                            trailing: PopupMenuButton(
                              itemBuilder: (ctx) => [
                                PopupMenuItem(value: 'toggle', child: Text(active ? 'Nonaktifkan' : 'Aktifkan')),
                              ],
                              onSelected: (v) {
                                if (v == 'toggle') _toggleActive(g);
                              },
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
