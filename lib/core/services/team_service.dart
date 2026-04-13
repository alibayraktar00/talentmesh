import 'package:supabase_flutter/supabase_flutter.dart';

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

      await _client.from('teams').insert({
        'name': name,
        'description': description,
        'max_members': maxMembers,
        'required_roles': requiredRoles,
        'required_skills': requiredSkills,
        'admin_id': user.id,
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('İşlem zaman aşımına uğradı. İnternet bağlantınızı veya veritabanı kurallarınızı (RLS) kontrol edin.');
      });

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
}
