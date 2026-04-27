class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final String status; // sent | delivered | read
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.status,
    required this.createdAt,
  });

  bool get isRead => status == 'read';
  bool get isDelivered => status == 'delivered' || status == 'read';

  ChatMessage copyWith({String? status}) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  static ChatMessage fromMap(Map<String, dynamic> row) {
    final createdAtRaw = row['created_at'];
    final createdAt = DateTime.tryParse(createdAtRaw?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return ChatMessage(
      id: (row['id'] ?? '').toString(),
      conversationId: (row['conversation_id'] ?? '').toString(),
      senderId: (row['sender_id'] ?? '').toString(),
      receiverId: (row['receiver_id'] ?? '').toString(),
      content: (row['content'] ?? '').toString(),
      status: (row['status'] ?? 'sent').toString(),
      createdAt: createdAt.toUtc(),
    );
  }
}

