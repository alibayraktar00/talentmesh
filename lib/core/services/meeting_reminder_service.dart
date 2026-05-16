import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

/// Uygulama açıkken yaklaşan toplantıları periyodik olarak kontrol eden
/// ve 24 saat içindeki toplantılar için hatırlatma bildirimi gönderen servis.
///
/// Client-side polling yaklaşımı kullanır.
/// Uygulama başlangıcında `start()` çağrılır, `dispose()` ile durdurulur.
class MeetingReminderService {
  MeetingReminderService._();
  static final MeetingReminderService _instance = MeetingReminderService._();
  static MeetingReminderService get instance => _instance;

  final _client = Supabase.instance.client;
  final _notificationService = NotificationService();

  Timer? _timer;
  bool _isRunning = false;

  /// Daha önce hatırlatma gönderilmiş toplantı ID'lerini hafızada tutar.
  /// Uygulama yeniden başlatıldığında sıfırlanır, ama DB tarafında
  /// duplicate kontrolü yapılır.
  final Set<String> _sentReminderIds = {};

  /// Hatırlatıcıyı başlatır. Hemen bir kontrol yapar, sonra her 30 dakikada bir tekrar eder.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // İlk kontrolü biraz geciktir (uygulama tam açılsın)
    Future.delayed(const Duration(seconds: 10), () {
      _checkUpcomingMeetings();
    });

    // Sonra her 30 dakikada bir kontrol et
    _timer = Timer.periodic(const Duration(minutes: 30), (_) {
      _checkUpcomingMeetings();
    });

    print('[MeetingReminder] Hatırlatıcı servisi başlatıldı.');
  }

  /// Hatırlatıcıyı durdurur.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    print('[MeetingReminder] Hatırlatıcı servisi durduruldu.');
  }

  /// Kullanıcının üye olduğu tüm takımlardaki 24 saat içindeki toplantıları kontrol eder.
  Future<void> _checkUpcomingMeetings() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now().toUtc();
      final in24Hours = now.add(const Duration(hours: 24));

      // 1. Kullanıcının kurucusu olduğu takım ID'leri
      final ownedTeamsRes = await _client
          .from('teams')
          .select('id')
          .eq('admin_id', user.id);
      final ownedTeamIds = List<Map<String, dynamic>>.from(ownedTeamsRes)
          .map((t) => t['id'].toString())
          .toList();

      // 2. Kullanıcının üye olduğu takım ID'leri
      final memberTeamsRes = await _client
          .from('team_members')
          .select('team_id')
          .eq('user_id', user.id);
      final memberTeamIds = List<Map<String, dynamic>>.from(memberTeamsRes)
          .map((t) => t['team_id'].toString())
          .toList();

      // 3. Birleştir (unique)
      final allTeamIds = {...ownedTeamIds, ...memberTeamIds}.toList();
      if (allTeamIds.isEmpty) return;

      // 4. 24 saat içindeki toplantıları çek
      final meetingsRes = await _client
          .from('team_meetings')
          .select('id, team_id, title, meeting_date')
          .inFilter('team_id', allTeamIds)
          .gte('meeting_date', now.toIso8601String())
          .lte('meeting_date', in24Hours.toIso8601String());

      final meetings = List<Map<String, dynamic>>.from(meetingsRes);
      if (meetings.isEmpty) return;

      print('[MeetingReminder] ${meetings.length} yaklaşan toplantı bulundu.');

      for (final meeting in meetings) {
        final meetingId = meeting['id'].toString();
        final teamId = meeting['team_id'].toString();
        final title = (meeting['title'] ?? '').toString();
        final meetingDate = DateTime.parse(meeting['meeting_date'].toString());

        // Zaten hatırlatma gönderdik mi? (hafıza kontrolü)
        if (_sentReminderIds.contains(meetingId)) continue;

        // DB'de bu toplantı için zaten hatırlatma var mı kontrol et
        final existingReminder = await _client
            .from('notifications')
            .select('id')
            .eq('user_id', user.id)
            .eq('type', 'meeting_reminder')
            .ilike('content', '%$title%')
            .limit(1)
            .maybeSingle();

        if (existingReminder != null) {
          _sentReminderIds.add(meetingId);
          continue;
        }

        // Takım adını al
        final teamRow = await _client
            .from('teams')
            .select('name')
            .eq('id', teamId)
            .maybeSingle();
        final teamName = (teamRow?['name'] ?? 'Takım').toString();

        // Takım üyelerini al
        final adminRes = await _client
            .from('teams')
            .select('admin_id')
            .eq('id', teamId)
            .maybeSingle();
        final adminId = adminRes?['admin_id']?.toString();

        final membersRes = await _client
            .from('team_members')
            .select('user_id')
            .eq('team_id', teamId);
        final memberIds = List<Map<String, dynamic>>.from(membersRes)
            .map((m) => m['user_id'].toString())
            .toList();

        if (adminId != null && !memberIds.contains(adminId)) {
          memberIds.add(adminId);
        }

        // Hatırlatma bildirimi gönder
        await _notificationService.notifyMeetingReminder(
          memberIds: memberIds,
          meetingTitle: title,
          teamName: teamName,
          meetingDate: meetingDate,
        );

        _sentReminderIds.add(meetingId);
        print('[MeetingReminder] "$title" toplantısı için hatırlatma gönderildi.');
      }
    } catch (e) {
      print('[MeetingReminder] Kontrol hatası: $e');
    }
  }
}
