import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;
  String? get userId => _userId;

  /// Giriş yapan kullanıcının profilini çek
  Future<Map<String, dynamic>?> fetchProfile() async {
    if (_userId == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', _userId!)
          .maybeSingle();
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Profil yoksa oluştur, varsa güncelle
  Future<void> upsertProfile(Map<String, dynamic> profile) async {
    if (_userId == null) return;
    profile['id'] = _userId;
    profile['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('profiles').upsert(profile);
  }

  /// Sadece belirli alanları güncelle
  Future<void> updateProfileField(Map<String, dynamic> fields) async {
    if (_userId == null) return;
    fields['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('profiles').update(fields).eq('id', _userId!);
  }

  /// Profil fotoğrafını yükle
  Future<String?> uploadAvatar(File imageFile) async {
    if (_userId == null) return null;
    try {
      final ext = imageFile.path.split('.').last;
      final path = 'avatars/$_userId.$ext';

      await _client.storage.from('avatars').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = _client.storage.from('avatars').getPublicUrl(path);
      await updateProfileField({'avatar_url': url});
      return url;
    } catch (e) {
      return null;
    }
  }

  /// Kullanıcının aldığı değerlendirmeleri çek
  Future<List<Map<String, dynamic>>> fetchReviews() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('reviews')
          .select()
          .eq('reviewed_id', _userId!)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Değerlendirme yaz
  Future<void> addReview({
    required String reviewedId,
    required int rating,
    required String comment,
  }) async {
    if (_userId == null) return;
    await _client.from('reviews').insert({
      'reviewer_id': _userId,
      'reviewed_id': reviewedId,
      'rating': rating,
      'comment': comment,
    });
  }
}
