import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_notification_model.dart';

class NotificationService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  // ──────────────────────── Okunmamış sayaç (Realtime) ────────────────────────

  Stream<int> watchUnreadCount() {
    final userId = _userId;
    if (userId == null) return Stream.value(0);

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) =>
            rows.where((r) => r['is_read'] != true).length);
  }

  // ──────────────────────── Bildirim listesi ────────────────────────

  Future<List<AppNotification>> fetchNotifications() async {
    final userId = _userId;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select('''
          *,
          actor:actor_id (
            id,
            username,
            full_name,
            avatar_url
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(AppNotification.fromJson)
        .toList();
  }

  // ──────────────────────── Okundu işaretleme ────────────────────────

  Future<void> markAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .inFilter('id', notificationIds);
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ──────────────────────── Bildirim oluşturma ────────────────────────

  Future<void> _insert({
    required String userId,
    required String type,
    required String title,
    required String content,
  }) async {
    final actorId = _userId;
    if (actorId == null || userId == actorId) return;

    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'actor_id': actorId,
        'type': type,
        'title': title,
        'content': content,
        'is_read': false,
      });
    } catch (e) {
      print('Bildirim oluşturulamadı ($type): $e');
    }
  }

  Future<String> _myDisplayName() async {
    final userId = _userId;
    if (userId == null) return 'Bir kullanıcı';

    final profile = await _client
        .from('profiles')
        .select('full_name, username')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return 'Bir kullanıcı';
    final fullName = (profile['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
    final username = (profile['username'] ?? '').toString().trim();
    if (username.isNotEmpty) return username;
    return 'Bir kullanıcı';
  }

  Future<void> notifyFriendRequest({required String addresseeId}) async {
    final name = await _myDisplayName();
    await _insert(
      userId: addresseeId,
      type: 'friend_request',
      title: 'Arkadaşlık İsteği',
      content: '$name sana arkadaşlık isteği gönderdi.',
    );
  }

  Future<void> notifyFriendAccepted({required String requesterId}) async {
    final name = await _myDisplayName();
    await _insert(
      userId: requesterId,
      type: 'friend_accepted',
      title: 'Arkadaşlık Kabul Edildi',
      content: '$name arkadaşlık isteğini kabul etti.',
    );
  }

  Future<void> notifyTeamInvite({
    required String memberUserId,
    required String teamName,
  }) async {
    final name = await _myDisplayName();
    await _insert(
      userId: memberUserId,
      type: 'team_invite',
      title: 'Takım Daveti',
      content: '$name seni $teamName takımına ekledi.',
    );
  }

  Future<void> notifyTeamJoinRequest({
    required String adminId,
    required String teamName,
  }) async {
    final name = await _myDisplayName();
    await _insert(
      userId: adminId,
      type: 'team_join_request',
      title: 'Takım Katılma İsteği',
      content: '$name, $teamName takımınıza katılma isteği gönderdi.',
    );
  }

  Future<void> notifyTeamJoinAccepted({
    required String memberUserId,
    required String teamName,
  }) async {
    await _insert(
      userId: memberUserId,
      type: 'team_join_accepted',
      title: 'Takım İsteği Onaylandı',
      content:
          '$teamName takımına yaptığınız katılım isteği yönetici tarafından onaylandı! Artık takımdasınız.',
    );
  }

  /// Spam önlemek için: konuşmada önceki mesaj yoksa veya son mesaj 1+ saat önceyse bildirim gönderir.
  Future<void> notifyMessageIfNeeded({
    required String receiverId,
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final previous = await _client
          .from('messages')
          .select('created_at')
          .eq('conversation_id', conversationId)
          .neq('id', messageId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      bool shouldNotify = previous == null;
      if (!shouldNotify) {
        final lastAt =
            DateTime.tryParse((previous['created_at'] ?? '').toString());
        if (lastAt != null &&
            DateTime.now().difference(lastAt).inHours >= 1) {
          shouldNotify = true;
        }
      }
      if (!shouldNotify) return;

      final name = await _myDisplayName();
      await _insert(
        userId: receiverId,
        type: 'message',
        title: 'Yeni Mesaj',
        content: '$name sana bir mesaj gönderdi.',
      );
    } catch (e) {
      print('Mesaj bildirimi oluşturulamadı: $e');
    }
  }

  // ──────────────────────── Görev Bildirimi ────────────────────────

  /// Görev atandığında, atanan her kişiye bildirim gönderir.
  Future<void> notifyTaskAssigned({
    required List<String> assigneeIds,
    required String taskTitle,
    required String teamName,
  }) async {
    final name = await _myDisplayName();
    for (final assigneeId in assigneeIds) {
      await _insert(
        userId: assigneeId,
        type: 'task_assigned',
        title: 'Yeni Görev Atandı',
        content: '$name sana "$taskTitle" görevini atadı. ($teamName)',
      );
    }
  }

  // ──────────────────────── Toplantı Bildirimi ────────────────────────

  /// Toplantı oluşturulduğunda tüm takım üyelerine bildirim gönderir.
  Future<void> notifyMeetingCreated({
    required List<String> memberIds,
    required String meetingTitle,
    required String teamName,
    required DateTime meetingDate,
  }) async {
    final name = await _myDisplayName();
    final dateStr =
        '${meetingDate.day.toString().padLeft(2, '0')}.${meetingDate.month.toString().padLeft(2, '0')}.${meetingDate.year} ${meetingDate.hour.toString().padLeft(2, '0')}:${meetingDate.minute.toString().padLeft(2, '0')}';
    for (final memberId in memberIds) {
      await _insert(
        userId: memberId,
        type: 'meeting_created',
        title: 'Yeni Toplantı Planlandı',
        content:
            '$name "$meetingTitle" toplantısı planladı. ($teamName — $dateStr)',
      );
    }
  }

  // ──────────────────────── Toplantı Hatırlatma ────────────────────────

  /// Toplantı günü yaklaştığında tüm takım üyelerine hatırlatma bildirimi gönderir.
  /// actor_id olmadan (sistem bildirimi olarak) gönderilir.
  Future<void> notifyMeetingReminder({
    required List<String> memberIds,
    required String meetingTitle,
    required String teamName,
    required DateTime meetingDate,
  }) async {
    final dateStr =
        '${meetingDate.day.toString().padLeft(2, '0')}.${meetingDate.month.toString().padLeft(2, '0')}.${meetingDate.year} ${meetingDate.hour.toString().padLeft(2, '0')}:${meetingDate.minute.toString().padLeft(2, '0')}';
    for (final memberId in memberIds) {
      try {
        await _client.from('notifications').insert({
          'user_id': memberId,
          'actor_id': null,
          'type': 'meeting_reminder',
          'title': 'Toplantı Hatırlatması',
          'content':
              '"$meetingTitle" toplantısı yaklaşıyor! ($teamName — $dateStr)',
          'is_read': false,
        });
      } catch (e) {
        print('Toplantı hatırlatma bildirimi oluşturulamadı: $e');
      }
    }
  }
}
