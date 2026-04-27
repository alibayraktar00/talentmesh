import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/chat/controllers/chat_controller.dart';
import '../core/chat/supabase_chat_repository.dart';
import '../core/chat/utils/chat_time_format.dart';
import '../core/theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isSending = false;
  bool _bootstrapping = true;

  final _client = Supabase.instance.client;
  late final SupabaseChatRepository _repo;
  ChatController? _controller;
  String? _conversationId;

  String? get _myId => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _repo = SupabaseChatRepository(client: _client);
    _bootstrap();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _bootstrap() async {
    final myId = _myId;
    if (myId == null) {
      if (mounted) setState(() => _bootstrapping = false);
      return;
    }

    try {
      final conversationId = await _repo.getOrCreateConversationId(
        otherUserId: widget.receiverId,
      );
      _conversationId = conversationId;

      final controller = ChatController(
        repo: _repo,
        conversationId: conversationId,
        myUserId: myId,
        otherUserId: widget.receiverId,
      );
      _controller = controller;
      await controller.init();
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  void _onScroll() {
    // reverse: true olduğu için "en üst" eski mesajlara gitmek demek;
    // scrollController position maxScrollExtent'a yaklaşınca loadMore.
    if (_controller == null) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _controller!.loadMore();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _controller?.dispose();
    _repo.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final myId = _myId;
    final text = _messageController.text.trim();
    if (myId == null) return;
    if (text.isEmpty || _isSending) return;
    if (_controller == null || _conversationId == null) return;

    setState(() => _isSending = true);
    try {
      await _controller!.send(text);
      _messageController.clear();
      // reverse listte en yeni altta (scroll offset 0) olduğu için yollayınca alta "snap" yapalım.
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj gönderilemedi: ${e.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj gönderilemedi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Icon _buildStatusIcon(String status) {
    if (status == 'read') {
      return const Icon(Icons.done_all, size: 14, color: Colors.lightBlue);
    }
    if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 14, color: Colors.grey);
    }
    return const Icon(Icons.check, size: 14, color: Colors.grey);
  }

  bool _isSameDay(DateTime aUtc, DateTime bUtc) {
    final a = aUtc.toLocal();
    final b = bUtc.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(DateTime utc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            ChatTimeFormat.dmy(utc),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedText,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = _myId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.receiverName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.headingText,
      ),
      body: Column(
        children: [
          Expanded(
            child: _bootstrapping
                ? const Center(child: CircularProgressIndicator())
                : (_controller == null
                    ? Center(
                        child: Text(
                          'Sohbet açılamadı.',
                          style: GoogleFonts.inter(color: AppColors.mutedText),
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _controller!,
                        builder: (context, _) {
                          final controller = _controller!;
                          final messages = controller.messagesDesc;
                          if (controller.isLoadingInitial) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (messages.isEmpty) {
                            return Center(
                              child: Text(
                                'Henüz mesaj yok. İlk mesajı sen gönder.',
                                style: GoogleFonts.inter(
                                  color: AppColors.mutedText,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            itemCount: messages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                if (!controller.hasMore) {
                                  return const SizedBox(height: 8);
                                }
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: controller.isLoadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const SizedBox(height: 18),
                                  ),
                                );
                              }

                              final message = messages[index];
                              final isMe = message.senderId == myId;
                              final timeText =
                                  ChatTimeFormat.hhmm(message.createdAt);
                              final status = message.status;

                              final bool showDateHeader = (index == messages.length - 1) ||
                                  !_isSameDay(
                                    message.createdAt,
                                    messages[index + 1].createdAt,
                                  );

                              return Column(
                                children: [
                                  if (showDateHeader)
                                    _buildDateHeader(message.createdAt),
                                  Align(
                                    alignment: isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context)
                                                .size
                                                .width *
                                            0.75,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppColors.primaryAccent
                                            : AppColors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(14),
                                          topRight: const Radius.circular(14),
                                          bottomLeft:
                                              Radius.circular(isMe ? 14 : 4),
                                          bottomRight:
                                              Radius.circular(isMe ? 4 : 14),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                                alpha: 0.05),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.content,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: isMe
                                                  ? AppColors.white
                                                  : AppColors.headingText,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                timeText,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: isMe
                                                      ? AppColors.white
                                                          .withValues(
                                                              alpha: 0.8)
                                                      : AppColors.mutedText,
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                _buildStatusIcon(status),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      )),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.chipBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
