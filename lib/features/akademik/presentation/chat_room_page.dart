import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../student/identity/student_identity_provider.dart';
import '../data/akademik_providers.dart';
import '../data/akademik_repository.dart';
import '../domain/akademik_models.dart';
import 'akademik_widgets.dart';

/// Ruang percakapan.
///
/// * Staff: pesan realtime lewat Supabase Realtime.
/// * Siswa: server tidak mengizinkan `anon` membaca `chat_messages` secara
///   langsung, jadi pesan baru diambil dengan polling ringan saat halaman aktif
///   (berhenti otomatis ketika halaman ditutup).
class ChatRoomPage extends ConsumerStatefulWidget {
  final AkademikAudience audience;
  final String threadId;
  final String? initialTitle;

  const ChatRoomPage({
    super.key,
    required this.audience,
    required this.threadId,
    this.initialTitle,
  });

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _uuid = const Uuid();

  final List<ChatMessage> _messages = [];
  final Set<String> _failed = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sending = false;
  Object? _error;

  RealtimeChannel? _channel;
  Timer? _poll;
  AkademikRepository? _repo;
  String? _myProfileId;
  String? _mySiswaId;

  bool get _isStaff => widget.audience == AkademikAudience.staff;

  @override
  void initState() {
    super.initState();
    _myProfileId = _isStaff ? ref.read(currentUserProvider).valueOrNull?.id : null;
    _mySiswaId = ref.read(studentIdentityProvider).siswaId;
    // Simpan referensi agar aman dipakai di dispose (setelah widget dilepas).
    _repo = ref.read(akademikRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    final channel = _channel;
    final repo = _repo;
    if (channel != null && repo != null) {
      // Pelepasan channel tidak boleh ditunggu di dispose.
      unawaited(repo.removeChannel(channel));
    }
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(akademikRepositoryProvider);
      final gateway = ref.read(studentGatewayProvider);

      final list = _isStaff
          ? await repo.fetchMessages(widget.threadId, limit: 30)
          : await gateway.fetchMessages(widget.threadId, limit: 30);

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
        _hasMore = list.length >= 30;
      });
      _subscribe();
      _markRead();
      _scrollToBottom(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _subscribe() {
    if (_isStaff) {
      _channel ??= ref.read(akademikRepositoryProvider).watchMessages(widget.threadId, (message) {
        if (!mounted) return;
        if (_messages.any((m) => m.id == message.id)) return;
        setState(() => _messages.add(message));
        _markRead();
        _scrollToBottom();
      });
    } else {
      _poll ??= Timer.periodic(const Duration(seconds: 10), (_) => _pollNew());
    }
  }

  Future<void> _pollNew() async {
    if (!mounted || _sending) return;
    try {
      final latest = await ref
          .read(studentGatewayProvider)
          .fetchMessages(widget.threadId, limit: 30);
      if (!mounted || latest.isEmpty) return;
      final known = _messages.map((m) => m.id).toSet();
      final baru = latest.where((m) => !known.contains(m.id)).toList();
      if (baru.isEmpty) return;
      setState(() => _messages.addAll(baru));
      _markRead();
      _scrollToBottom();
    } catch (_) {
      // Polling gagal (mis. jaringan putus) — coba lagi pada tick berikutnya.
    }
  }

  Future<void> _markRead() async {
    try {
      if (_isStaff) {
        await ref.read(akademikRepositoryProvider).markThreadRead(widget.threadId);
      } else {
        await ref.read(studentGatewayProvider).markThreadRead(widget.threadId);
      }
    } catch (_) {
      // Badge belum terbaca bukan alasan menggagalkan halaman.
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final before = _messages.first.createdAt;
      final older = _isStaff
          ? await ref.read(akademikRepositoryProvider).fetchMessages(widget.threadId, before: before)
          : await ref
              .read(studentGatewayProvider)
              .fetchMessages(widget.threadId, before: before);
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older.where((m) => !_messages.any((e) => e.id == m.id)));
        _hasMore = older.length >= 30;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _send({ChatMessage? retry}) async {
    final body = (retry?.body ?? _text.text).trim();
    if (body.isEmpty || _sending) return;

    final clientId = _uuid.v4();
    final senderNama = _isStaff
        ? (ref.read(currentUserProvider).valueOrNull?.fullName ?? 'Guru')
        : (ref.read(studentIdentityProvider).siswaNama ?? 'Siswa');

    final optimistic = ChatMessage(
      id: 'local-$clientId',
      threadId: widget.threadId,
      senderProfileId: _myProfileId,
      senderSiswaId: _mySiswaId,
      senderNama: senderNama,
      body: body,
      createdAt: DateTime.now(),
      pending: true,
    );

    setState(() {
      _sending = true;
      if (retry == null) {
        _text.clear();
      } else {
        // Buang gelembung gagal lama; pesan baru dikirim dengan client_id baru.
        _failed.remove(retry.id);
        _messages.removeWhere((m) => m.id == retry.id);
      }
      _messages.add(optimistic);
    });
    _scrollToBottom();

    try {
      final sent = _isStaff
          ? await ref.read(akademikRepositoryProvider).sendMessage(
                widget.threadId,
                body,
                clientId: clientId,
                senderNama: senderNama,
              )
          : await ref.read(studentGatewayProvider).sendMessage(
                widget.threadId,
                body,
                clientId: clientId,
              );

      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == optimistic.id);
        if (sent != null && !_messages.any((m) => m.id == sent.id)) _messages.add(sent);
        _sending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed.add(optimistic.id);
        _sending = false;
      });
      akademikSnack(
        context,
        'Pesan gagal terkirim. Periksa koneksi lalu ketuk pesan untuk mencoba lagi.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialTitle ??
        (_isStaff ? 'Percakapan' : 'Chat dengan guru');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              _isStaff ? 'Pesan terenkripsi saat transit' : 'Diverifikasi server',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const AppLoading(message: 'Memuat pesan…');
    if (_error != null) {
      return AkademikErrorView(error: _error!, onRetry: _load);
    }
    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Belum ada pesan',
            subtitle: 'Kirim pesan pertama untuk memulai percakapan. Pesan hanya terlihat oleh anggota percakapan ini.',
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      itemCount: _messages.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_hasMore && index == 0) {
          return Center(
            child: _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(onPressed: _loadOlder, child: const Text('Muat pesan lama')),
          );
        }
        final msg = _messages[_hasMore ? index - 1 : index];
        final mine = msg.isMine(profileId: _myProfileId, siswaId: _mySiswaId);
        final failed = _failed.contains(msg.id);
        return _MessageBubble(
          message: msg,
          mine: mine,
          failed: failed,
          onRetry: failed ? () => _send(retry: msg) : null,
        );
      },
    );
  }

  Widget _buildComposer() {
    final canSend = !_sending;
    return SafeArea(
      top: false,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan…',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              tooltip: 'Kirim',
              onPressed: canSend ? () => _send() : null,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool failed;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.failed,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine ? AppColors.primary : AppColors.surface;
    final textColor = mine ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    message.senderNama,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                  ),
                ),
              Material(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mine ? 14 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 14),
                ),
                child: InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      border: mine ? null : Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(mine ? 14 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 14),
                      ),
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(fontSize: 13.5, color: textColor, height: 1.4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Text(
                  failed
                      ? 'Gagal terkirim • ketuk untuk coba lagi'
                      : message.pending
                          ? 'Mengirim…'
                          : formatJam(message.createdAt),
                  style: TextStyle(
                    fontSize: 9.5,
                    color: failed ? AppColors.error : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
