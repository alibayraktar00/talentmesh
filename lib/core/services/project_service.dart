import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectService {
  final _client = Supabase.instance.client;

  /// Tüm projeleri çek (en yeniden eskiye)
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    final data = await _client
        .from('projects')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Yeni proje ekle
  Future<void> createProject(Map<String, dynamic> project) async {
    await _client.from('projects').insert(project);
  }

  /// Proje sil
  Future<void> deleteProject(String id) async {
    await _client.from('projects').delete().eq('id', id);
  }
}
