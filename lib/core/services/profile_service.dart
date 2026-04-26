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
  Future<List<Map<String, dynamic>>> fetchReviews([String? targetUserId]) async {
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
      if (_userId == null) throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

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

  /// 2. Yeni Yetenek Ekleme (Add Skill)
  Future<void> addSkill(String newSkill) async {
    try {
      if (_userId == null) throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

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
      if (_userId == null) throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

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
  Future<void> updateEducation(String school, String department, String educationYear, String degree) async {
    try {
      if (_userId == null) throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

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
      if (_userId == null) throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

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
      if (_userId == null) throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

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
      if (_userId == null) throw Exception('Oturum açmış bir kullanıcı bulunamadı.');

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
