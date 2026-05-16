class AppNotification {
  final String id;
  final String userId;
  final String? actorId;
  final String type;
  final String title;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? actorProfile;

  const AppNotification({
    required this.id,
    required this.userId,
    this.actorId,
    required this.type,
    required this.title,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.actorProfile,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    return AppNotification(
      id: json['id'].toString(),
      userId: (json['user_id'] ?? '').toString(),
      actorId: json['actor_id']?.toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      actorProfile: actor is Map<String, dynamic> ? actor : null,
    );
  }

  String get actorDisplayName {
    final profile = actorProfile;
    if (profile == null) return '';
    final fullName = (profile['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
    return (profile['username'] ?? '').toString();
  }

  String? get actorAvatarUrl {
    final url = actorProfile?['avatar_url']?.toString();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  String get actorInitial {
    final name = actorDisplayName;
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}
