import 'dart:async';

import 'package:flutter/foundation.dart';

import '../chat_repository.dart';
import '../models/message.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ChatRepository repo,
    required this.conversationId,
    required this.myUserId,
    required this.otherUserId,
    this.pageSize = 30,
  }) : _repo = repo;

  final ChatRepository _repo;
  final String conversationId;
  final String myUserId;
  final String otherUserId;
  final int pageSize;

  final List<ChatMessage> _messagesDesc = [];
  List<ChatMessage> get messagesDesc => List.unmodifiable(_messagesDesc);

  bool _isLoadingInitial = false;
  bool get isLoadingInitial => _isLoadingInitial;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  StreamSubscription<ChatMessage>? _eventsSub;

  Future<void> init() async {
    if (_isLoadingInitial) return;
    _isLoadingInitial = true;
    notifyListeners();

    try {
      final page = await _repo.fetchMessagesPage(
        conversationId: conversationId,
        limit: pageSize,
      );
      _messagesDesc
        ..clear()
        ..addAll(page);
      _hasMore = page.length == pageSize;
      _wireRealtime();
      await _deliverAndReadIfNeeded();
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  void _wireRealtime() {
    _eventsSub?.cancel();
    _eventsSub = _repo
        .watchConversationEvents(conversationId: conversationId)
        .listen((eventMsg) {
      // Insert/Update event: listeyi id ile upsert edelim.
      final idx = _messagesDesc.indexWhere((m) => m.id == eventMsg.id);
      if (idx >= 0) {
        _messagesDesc[idx] = eventMsg;
      } else {
        _messagesDesc.insert(0, eventMsg);
      }
      notifyListeners();

      // Eğer bana geldiyse delivered/read akışını tetikle.
      if (eventMsg.receiverId == myUserId) {
        _deliverAndReadIfNeeded();
      }
    });
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_messagesDesc.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final oldest = _messagesDesc.last.createdAt;
      final page = await _repo.fetchMessagesPage(
        conversationId: conversationId,
        limit: pageSize,
        beforeUtc: oldest,
      );
      if (page.isEmpty) {
        _hasMore = false;
      } else {
        _messagesDesc.addAll(page);
        _hasMore = page.length == pageSize;
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final inserted = await _repo.sendMessage(
      conversationId: conversationId,
      receiverId: otherUserId,
      content: trimmed,
    );

    // Optimistic: realtime event gecikse bile mesaj anında görünsün.
    // (Realtime ile aynı id gelirse upsert zaten update edecektir.)
    final existingIdx = _messagesDesc.indexWhere((m) => m.id == inserted.id);
    if (existingIdx >= 0) {
      _messagesDesc[existingIdx] = inserted;
    } else {
      _messagesDesc.insert(0, inserted);
    }
    notifyListeners();
  }

  Future<void> markReadNow() async {
    await _repo.markRead(conversationId: conversationId, otherUserId: otherUserId);
  }

  Future<void> _deliverAndReadIfNeeded() async {
    // Bana gelen "sent" olanları delivered yap.
    final toDeliver = _messagesDesc
        .where((m) =>
            m.receiverId == myUserId &&
            m.senderId == otherUserId &&
            m.status == 'sent')
        .map((m) => m.id)
        .toList();
    if (toDeliver.isNotEmpty) {
      // ignore: unawaited_futures
      _repo.markDelivered(conversationId: conversationId, messageIds: toDeliver);
    }

    // Chat açıkken bana gelen read olmayanları read yap (tek RPC ile).
    final hasUnreadFromOther = _messagesDesc.any((m) =>
        m.receiverId == myUserId &&
        m.senderId == otherUserId &&
        m.status != 'read');
    if (hasUnreadFromOther) {
      // ignore: unawaited_futures
      _repo.markRead(conversationId: conversationId, otherUserId: otherUserId);
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }
}

