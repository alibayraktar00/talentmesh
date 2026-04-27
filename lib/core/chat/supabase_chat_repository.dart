import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_repository.dart';
import 'models/conversation.dart';
import 'models/message.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channelsByConversationId = {};

  String? get _myId => _client.auth.currentUser?.id;

  @override
  Stream<List<Conversation>> watchInbox() {
    // Not: `conversations_inbox` view öneriliyor (aşağıda SQL kısmında verilecek).
    // Fallback: direkt `conversations` çekilebilir ama "other_profile" join'i olmaz.
    return _client
        .from('conversations_inbox')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((rows) {
          final myId = _myId;
          if (myId == null) return <Conversation>[];
          return rows
              .map((r) => Conversation.fromMap(row: r, myUserId: myId))
              .toList();
        });
  }

  @override
  Future<String> getOrCreateConversationId({required String otherUserId}) async {
    final myId = _myId;
    if (myId == null) {
      throw const AuthException('No active session');
    }
    final res = await _client.rpc(
      'get_or_create_conversation',
      params: {'p_other_user_id': otherUserId},
    );
    // RPC `uuid` döndürebilir; supabase dart bazen Map döner. String'e normalize.
    return res.toString();
  }

  @override
  Future<List<ChatMessage>> fetchMessagesPage({
    required String conversationId,
    required int limit,
    DateTime? beforeUtc,
  }) async {
    var q = _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);

    if (beforeUtc != null) {
      q = q.lt('created_at', beforeUtc.toIso8601String());
    }

    final rows = await q
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows)
        .map(ChatMessage.fromMap)
        .toList();
  }

  @override
  Stream<ChatMessage> watchConversationEvents({
    required String conversationId,
  }) {
    final controller = StreamController<ChatMessage>.broadcast();

    final channel = _client.channel('conversation-$conversationId');
    _channelsByConversationId[conversationId] = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            controller.add(ChatMessage.fromMap(record));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            controller.add(ChatMessage.fromMap(record));
          },
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.closed) {
            if (!controller.isClosed) controller.close();
          }
        });

    controller.onCancel = () {
      final ch = _channelsByConversationId.remove(conversationId);
      if (ch != null) _client.removeChannel(ch);
    };

    return controller.stream;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
  }) async {
    final myId = _myId;
    if (myId == null) {
      throw const AuthException('No active session');
    }
    final inserted = await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': myId,
      'receiver_id': receiverId,
      'content': content,
      'status': 'sent',
    }).select().single();

    return ChatMessage.fromMap(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<void> markDelivered({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final myId = _myId;
    if (myId == null) return;

    await _client
        .from('messages')
        .update({'status': 'delivered'})
        .inFilter('id', messageIds)
        .eq('conversation_id', conversationId)
        .eq('receiver_id', myId)
        .eq('status', 'sent');
  }

  @override
  Future<void> markRead({
    required String conversationId,
    required String otherUserId,
  }) async {
    // Hem unread_count reset + mesaj status update'i için RPC öneriyoruz.
    await _client.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  @override
  Future<void> dispose() async {
    final channels = _channelsByConversationId.values.toList();
    _channelsByConversationId.clear();
    for (final ch in channels) {
      _client.removeChannel(ch);
    }
  }
}

