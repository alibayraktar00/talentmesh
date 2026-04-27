import 'dart:async';

import 'models/conversation.dart';
import 'models/message.dart';

abstract class ChatRepository {
  Stream<List<Conversation>> watchInbox();

  Future<String> getOrCreateConversationId({required String otherUserId});

  /// Pagination: en yeni mesajlar ilk sayfada gelir (descending).
  Future<List<ChatMessage>> fetchMessagesPage({
    required String conversationId,
    required int limit,
    DateTime? beforeUtc,
  });

  /// Realtime: yeni mesaj insert + status update'leri için event stream.
  Stream<ChatMessage> watchConversationEvents({
    required String conversationId,
  });

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
  });

  Future<void> markDelivered({
    required String conversationId,
    required List<String> messageIds,
  });

  Future<void> markRead({
    required String conversationId,
    required String otherUserId,
  });

  Future<void> dispose();
}

class ConversationEvent {
  final ChatMessage message;
  const ConversationEvent(this.message);
}

