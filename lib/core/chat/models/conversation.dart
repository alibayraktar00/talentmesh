class Conversation {
  final String id;
  final String userA;
  final String userB;

  // Denormalize edilen alanlar (Inbox performansı için)
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? lastMessageStatus;

  // Inbox badge için (bu konuşmada BENİM unread sayım)
  final int myUnreadCount;

  // Inbox item için karşı taraf bilgisi (join/view ile doldurulabilir)
  final String otherUserId;
  final String? otherUsername;
  final String? otherFullName;

  const Conversation({
    required this.id,
    required this.userA,
    required this.userB,
    required this.otherUserId,
    required this.myUnreadCount,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    this.otherUsername,
    this.otherFullName,
  });

  String displayName() {
    final full = (otherFullName ?? '').trim();
    if (full.isNotEmpty) return full;
    final u = (otherUsername ?? '').trim();
    if (u.isNotEmpty) return '@$u';
    return 'Kullanıcı';
  }

  static Conversation fromMap({
    required Map<String, dynamic> row,
    required String myUserId,
  }) {
    final userA = (row['user_a'] ?? '').toString();
    final userB = (row['user_b'] ?? '').toString();
    final otherUserId = userA == myUserId ? userB : userA;

    final lastAtRaw = row['last_message_at'];
    final lastAt = lastAtRaw == null
        ? null
        : DateTime.tryParse(lastAtRaw.toString())?.toUtc();

    int myUnreadCount = 0;
    if (myUserId == userA) {
      myUnreadCount = (row['unread_count_a'] ?? 0) as int;
    } else if (myUserId == userB) {
      myUnreadCount = (row['unread_count_b'] ?? 0) as int;
    }

    // İsteğe bağlı: view üzerinden profile join'leri.
    final otherProfile =
        (row['other_profile'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return Conversation(
      id: (row['id'] ?? '').toString(),
      userA: userA,
      userB: userB,
      otherUserId: otherUserId,
      myUnreadCount: myUnreadCount,
      lastMessageText: row['last_message_text']?.toString(),
      lastMessageSenderId: row['last_message_sender_id']?.toString(),
      lastMessageStatus: row['last_message_status']?.toString(),
      lastMessageAt: lastAt,
      otherUsername: otherProfile['username']?.toString(),
      otherFullName: otherProfile['full_name']?.toString(),
    );
  }
}

