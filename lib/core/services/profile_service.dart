import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;
  String? get userId => _userId;

  /// Giriş yapan kullanıcının profilini çek
  Future<Map<String, dynamic>?> fetchProfile([String? targetUserId]) async {
    final idToUse = targetUserId ?? _userId;
    if (idToUse == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', idToUse)
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

      await _client.storage
          .from('avatars')
          .upload(
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
  Future<List<Map<String, dynamic>>> fetchReviews([
    String? targetUserId,
  ]) async {
    final idToUse = targetUserId ?? _userId;
    if (idToUse == null) return [];
    try {
      final data = await _client
          .from('reviews')
          .select()
          .eq('reviewed_id', idToUse)
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

  /// 1. Bölüm Güncelleme (Update Department)
  Future<void> updateDepartment(String department) async {
    try {
      if (_userId == null)
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

      await _client
          .from('profiles')
          .update({'department': department})
          .eq('id', _userId!);

      print('Bölüm başarıyla güncellendi: $department');
    } catch (e) {
      print('Bölüm güncellenirken bir hata oluştu: $e');
      rethrow;
    }
  }

  /// İki kullanıcının arkadaş olup olmadığını kontrol et
  Future<bool> areUsersFriends(String user1, String user2) async {
    try {
      final response = await _client
          .from('friend_requests')
          .select()
          .eq('status', 'accepted')
          .eq('request_type', 'friend')
          .or('and(requester_id.eq.$user1,addressee_id.eq.$user2),and(requester_id.eq.$user2,addressee_id.eq.$user1)')
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('Arkadaşlık kontrolü hatası: $e');
      return false;
    }
  }

  /// Kullanıcının yetenek onaylarını getir
  Future<List<Map<String, dynamic>>> fetchSkillEndorsements([
    String? targetUserId,
  ]) async {
    final idToUse = targetUserId ?? _userId;
    if (idToUse == null) return [];
    try {
      final data = await _client
          .from('skill_endorsements')
          .select()
          .eq('user_id', idToUse);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Yetenek onayları çekilirken hata: $e');
      return [];
    }
  }

  /// Yetenek onayını ekle veya çıkar (Toggle)
  Future<void> toggleSkillEndorsement({
    required String targetUserId,
    required String skillName,
    required bool isCurrentlyEndorsed,
  }) async {
    if (_userId == null || _userId == targetUserId) return;
    
    try {
      if (isCurrentlyEndorsed) {
        // Onayı kaldır
        await _client
            .from('skill_endorsements')
            .delete()
            .match({
              'user_id': targetUserId,
              'endorser_id': _userId!,
              'skill_name': skillName,
            });
      } else {
        // Onay ekle
        await _client.from('skill_endorsements').insert({
          'user_id': targetUserId,
          'endorser_id': _userId!,
          'skill_name': skillName,
        });
      }
    } catch (e) {
      print('Yetenek onayı güncellenirken hata: $e');
      rethrow;
    }
  }

  /// 2. Yeni Yetenek Ekleme (Add Skill)
  Future<void> addSkill(String newSkill) async {
    try {
      if (_userId == null)
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

      final data = await _client
          .from('profiles')
          .select('skills')
          .eq('id', _userId!)
          .maybeSingle();

      List<String> currentSkills = [];
      if (data != null && data['skills'] != null) {
        currentSkills = List<String>.from(data['skills']);
      }

      if (!currentSkills.contains(newSkill.trim())) {
        currentSkills.add(newSkill.trim());

        await _client
            .from('profiles')
            .update({'skills': currentSkills})
            .eq('id', _userId!);

        print('Yetenek başarıyla eklendi: $newSkill');
      } else {
        print('Bu yetenek zaten profilde mevcut.');
      }
    } catch (e) {
      print('Yetenek eklenirken bir hata oluştu: $e');
      rethrow;
    }
  }

  /// 3. Aranan Proje Türlerini Güncelleme (Update Looking For)
  Future<void> updateLookingFor(List<String> lookingForList) async {
    try {
      if (_userId == null)
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

      await _client
          .from('profiles')
          .update({'looking_for': lookingForList})
          .eq('id', _userId!);

      print('Aranan kriterler başarıyla güncellendi.');
    } catch (e) {
      print('Aranan kriterler güncellenirken bir hata oluştu: $e');
      rethrow;
    }
  }

  /// 4. Eğitim Bilgilerini Güncelleme (Update Education)
  Future<void> updateEducation(
    String school,
    String department,
    String educationYear,
    String degree,
  ) async {
    try {
      if (_userId == null)
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

      await _client
          .from('profiles')
          .update({
            'school': school,
            'department': department,
            'education_year': educationYear,
            'degree': degree,
          })
          .eq('id', _userId!);

      print('Eğitim bilgileri başarıyla güncellendi.');
    } catch (e) {
      print('Eğitim güncellenirken bir hata oluştu: $e');
      rethrow;
    }
  }

  /// 5. Yeni Rol Ekleme (addLookingForRole)
  Future<void> addLookingForRole(String role) async {
    try {
      if (_userId == null)
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

      final data = await _client
          .from('profiles')
          .select('looking_for')
          .eq('id', _userId!)
          .maybeSingle();

      List<String> currentRoles = [];
      if (data != null && data['looking_for'] != null) {
        currentRoles = List<String>.from(data['looking_for']);
      }

      if (!currentRoles.contains(role.trim())) {
        currentRoles.add(role.trim());

        await _client
            .from('profiles')
            .update({'looking_for': currentRoles})
            .eq('id', _userId!);

        print('Rol tercihi başarıyla eklendi: $role');
      } else {
        print('Bu rol tercihi zaten profilde mevcut.');
      }
    } catch (e) {
      print('Rol tercihi eklenirken bir hata oluştu: $e');
      rethrow;
    }
  }

  /// 'open_to_work' drumunu güncelleyen özel metot
  Future<void> updateOpenToWork(bool value) async {
    try {
      if (_userId == null)
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

      await _client
          .from('profiles')
          .update({
            'open_to_work': value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _userId!);

      print('İşe açık durumu başarıyla güncellendi: $value');
    } catch (e) {
      print('İşe açık durumu güncellenirken bir hata oluştu: $e');
      rethrow;
    }
  }

  /// jsonb ve diğer alanlar için Jenerik Güncelleme Metodu
  Future<void> updateDynamicProfileField(String fieldName, dynamic data) async {
    try {
      if (_userId == null)
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

      await _client
          .from('profiles')
          .update({
            fieldName: data,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _userId!);

      print('$fieldName alanı başarıyla güncellendi.');
    } catch (e) {
      print('$fieldName güncellenirken bir hata oluştu: $e');
      rethrow;
    }
  }
}
