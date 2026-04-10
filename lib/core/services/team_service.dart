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
      });

      print('Takım başarıyla oluşturuldu: $name');
    } catch (e) {
      print('Takım oluşturulurken hata: $e');
      rethrow;
    }
  }
}
