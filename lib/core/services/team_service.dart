import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/meeting_model.dart';

class TeamService {
  final _client = Supabase.instance.client;

  /// Yeni takım oluşturur ve "teams" tablosuna ekler.
  /// auth.currentUser üzerinden admin_id otomatik alınır.
  Future<void> createTeam({
    required String name,
    required String description,
    required int maxMembers,
    required List<String> requiredRoles,
    required List<String> requiredSkills,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');
      }

      await _client
          .from('teams')
          .insert({
            'name': name,
            'description': description,
            'max_members': maxMembers,
            'required_roles': requiredRoles,
            'required_skills': requiredSkills,
            'admin_id': user.id,
          })
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'İşlem zaman aşımına uğradı. İnternet bağlantınızı veya veritabanı kurallarınızı (RLS) kontrol edin.',
              );
            },
          );

      print('Takım başarıyla oluşturuldu: $name');
    } catch (e) {
      print('Takım oluşturulurken hata: $e');
      rethrow;
    }
  }

  /// Takımı siler
  Future<void> deleteTeam(String teamId) async {
    try {
      await _client.from('teams').delete().eq('id', teamId);
    } catch (e) {
      print('Takım silinirken hata: $e');
      rethrow;
    }
  }

  /// Takım açıklamasını günceller
  Future<void> updateTeamDescription(
    String teamId,
    String newDescription,
  ) async {
    try {
      await _client
          .from('teams')
          .update({'description': newDescription})
          .eq('id', teamId);
    } catch (e) {
      print('Takım açıklaması güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Takımdan üye çıkarır
  Future<void> removeTeamMember(String membershipId) async {
    try {
      await _client.from('team_members').delete().eq('id', membershipId);
    } catch (e) {
      print('Takımdan üye çıkarılırken hata: $e');
      rethrow;
    }
  }

  /// Oturum açmış kullanıcının kurucusu olduğu takımları getirir (Real-time).
  Stream<List<Map<String, dynamic>>> getUserTeamsStream() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    return _client
        .from('teams')
        .stream(primaryKey: ['id'])
        .eq('admin_id', user.id)
        .order('created_at', ascending: false);
  }

  /// Mevcut oturum açmış kullanıcının kimliği.
  String? get currentUserId => _client.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════════════════
  // TOPLANTI (MEETING) İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════════

  /// Yeni bir takım toplantısı oluşturur.
  Future<void> createMeeting({
    required String teamId,
    required String title,
    String? description,
    required DateTime meetingDate,
    String? meetingLink,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');
      }

      await _client.from('team_meetings').insert({
        'team_id': teamId,
        'created_by': user.id,
        'title': title,
        'description': description,
        'meeting_date': meetingDate.toIso8601String(),
        'meeting_link': meetingLink,
      });
      print('Toplantı oluşturuldu: $title');
    } on PostgrestException catch (e) {
      print('Toplantı oluşturma (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Toplantı oluşturma hatası: $e');
      rethrow;
    }
  }

  /// Belirli bir takıma ait tüm toplantıları çeker.
  Future<List<Meeting>> fetchTeamMeetings(String teamId) async {
    try {
      // profiles tablosu ile JOIN yaparak oluşturan kişinin bilgilerini de çekiyoruz
      final response = await _client
          .from('team_meetings')
          .select('''
            *,
            profiles:created_by (
              id,
              username,
              full_name,
              avatar_url,
              department
            )
          ''')
          .eq('team_id', teamId)
          .order('meeting_date', ascending: true);

      final List<Meeting> meetings = (response as List)
          .map((item) => Meeting.fromJson(item as Map<String, dynamic>))
          .toList();

      return meetings;
    } on PostgrestException catch (e) {
      print('Toplantıları çekerken (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Toplantıları çekerken hata: $e');
      rethrow;
    }
  }

  /// Toplantı silme
  Future<void> deleteMeeting(String meetingId) async {
    try {
      await _client.from('team_meetings').delete().eq('id', meetingId);
      print('Toplantı silindi: $meetingId');
    } on PostgrestException catch (e) {
      print('Toplantı silme (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Toplantı silme hatası: $e');
      rethrow;
    }
  }
}
