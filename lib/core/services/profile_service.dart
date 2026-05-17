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
      final path = '$_userId.$ext'; // avatars/ prefix'i kaldirildi, zaten avatars bucket'indayiz

      await _client.storage
          .from('avatars')
          .upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = _client.storage.from('avatars').getPublicUrl(path);
      print('Fotoğraf yüklendi, URL: $url');
      await updateProfileField({'avatar_url': url});
      return url;
    } catch (e) {
      print('Fotoğraf yükleme hatası: $e');
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
      final outgoing = await _client
          .from('friend_requests')
          .select('id')
          .eq('requester_id', user1)
          .eq('addressee_id', user2)
          .eq('status', 'accepted')
          .eq('request_type', 'friend')
          .maybeSingle();
      if (outgoing != null) return true;

      final incoming = await _client
          .from('friend_requests')
          .select('id')
          .eq('requester_id', user2)
          .eq('addressee_id', user1)
          .eq('status', 'accepted')
          .eq('request_type', 'friend')
          .maybeSingle();
      return incoming != null;
    } catch (e) {
      print('Arkadaşlık kontrolü hatası: $e');
      return false;
    }
  }

  /// İki kullanıcı arasındaki accepted arkadaşlık satır id'lerini bulur.
  Future<List<String>> _findAcceptedFriendshipIds(
    String myId,
    String friendUserId,
  ) async {
    final ids = <String>{};

    Future<void> collectFromQuery(dynamic query) async {
      final rows = List<Map<String, dynamic>>.from(await query);
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }

    // Önce request_type=friend ile dene
    await collectFromQuery(
      _client
          .from('friend_requests')
          .select('id')
          .eq('requester_id', myId)
          .eq('addressee_id', friendUserId)
          .eq('status', 'accepted')
          .eq('request_type', 'friend'),
    );
    await collectFromQuery(
      _client
          .from('friend_requests')
          .select('id')
          .eq('requester_id', friendUserId)
          .eq('addressee_id', myId)
          .eq('status', 'accepted')
          .eq('request_type', 'friend'),
    );

    // Eski kayıtlar için request_type filtresi olmadan dene
    if (ids.isEmpty) {
      await collectFromQuery(
        _client
            .from('friend_requests')
            .select('id')
            .eq('requester_id', myId)
            .eq('addressee_id', friendUserId)
            .eq('status', 'accepted'),
      );
      await collectFromQuery(
        _client
            .from('friend_requests')
            .select('id')
            .eq('requester_id', friendUserId)
            .eq('addressee_id', myId)
            .eq('status', 'accepted'),
      );
    }

    return ids.toList();
  }

  /// Arkadaşlık kaydını kaldırır (RLS bypass için RPC kullanır).
  Future<bool> removeFriend(String friendUserId) async {
    final myId = _userId;
    if (myId == null) return false;

    try {
      await _client.rpc('remove_friend', params: {
        'my_user_id': myId,
        'friend_user_id': friendUserId,
      });
      return true;
    } on PostgrestException catch (e) {
      print('Arkadaşlıktan çıkarma (Postgrest): ${e.message}');
      rethrow;
    } catch (e) {
      print('Arkadaşlıktan çıkarma hatası: $e');
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

  // ──────────────────────── Görünürlük Ayarları ────────────────────────

  /// Kullanıcının görünürlük ayarlarını Supabase'den çeker.
  Future<Map<String, bool>> fetchVisibilitySettings() async {
    if (_userId == null) {
      return {'is_profile_public': true, 'show_email': false};
    }
    try {
      final data = await _client
          .from('profiles')
          .select('is_profile_public, show_email')
          .eq('id', _userId!)
          .maybeSingle();
      if (data == null) return {'is_profile_public': true, 'show_email': false};
      return {
        'is_profile_public': (data['is_profile_public'] as bool?) ?? true,
        'show_email': (data['show_email'] as bool?) ?? false,
      };
    } catch (e) {
      print('Görünürlük ayarları çekilirken hata: $e');
      return {'is_profile_public': true, 'show_email': false};
    }
  }

  /// Görünürlük ayarlarını Supabase'e kaydeder.
  Future<void> updateVisibilitySettings({
    required bool isProfilePublic,
    required bool showEmail,
  }) async {
    if (_userId == null) return;
    try {
      await _client.from('profiles').update({
        'is_profile_public': isProfilePublic,
        'show_email': showEmail,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _userId!);
    } catch (e) {
      print('Görünürlük ayarları kaydedilirken hata: $e');
      rethrow;
    }
  }

  // ──────────────────────── Bildirim Ayarları ────────────────────────

  /// Kullanıcının bildirim tercihlerini Supabase'den çeker.
  Future<Map<String, bool>> fetchNotificationSettings() async {
    if (_userId == null) {
      return {
        'notif_messages': true,
        'notif_connections': true,
        'notif_team_updates': true,
      };
    }
    try {
      final data = await _client
          .from('profiles')
          .select('notif_messages, notif_connections, notif_team_updates')
          .eq('id', _userId!)
          .maybeSingle();
      if (data == null) {
        return {
          'notif_messages': true,
          'notif_connections': true,
          'notif_team_updates': true,
        };
      }
      return {
        'notif_messages': (data['notif_messages'] as bool?) ?? true,
        'notif_connections': (data['notif_connections'] as bool?) ?? true,
        'notif_team_updates': (data['notif_team_updates'] as bool?) ?? true,
      };
    } catch (e) {
      print('Bildirim ayarları çekilirken hata: $e');
      return {
        'notif_messages': true,
        'notif_connections': true,
        'notif_team_updates': true,
      };
    }
  }

  /// Bildirim tercihlerini Supabase'e kaydeder.
  Future<void> updateNotificationSettings({
    required bool messages,
    required bool connections,
    required bool teamUpdates,
  }) async {
    if (_userId == null) return;
    try {
      await _client.from('profiles').update({
        'notif_messages': messages,
        'notif_connections': connections,
        'notif_team_updates': teamUpdates,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _userId!);
    } catch (e) {
      print('Bildirim ayarları kaydedilirken hata: $e');
      rethrow;
    }
  }

  // ──────────────────────── Kullanıcı Tercihi Kontrolü ────────────────────────

  /// Belirli bir kullanıcının profiles tablosundaki boolean tercihini döner.
  /// Bildirim servisi tarafından göndermeden önce alıcının tercihini kontrol etmek için kullanılır.
  Future<bool> fetchUserPref(String userId, String column) async {
    try {
      final data = await _client
          .from('profiles')
          .select(column)
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return true;
      return (data[column] as bool?) ?? true;
    } catch (_) {
      return true; // hata varsa bildirimi gönder
    }
  }

  // ──────────────────────── Arkadaş Sayısı ────────────────────────

  /// Belirtilen kullanıcının toplam arkadaş sayısını döner.
  /// RLS'yi bypass etmek için Supabase RPC fonksiyonu kullanır.
  Future<int> fetchFriendCount(String targetUserId) async {
    try {
      final result = await _client.rpc(
        'get_friend_count',
        params: {'target_user_id': targetUserId},
      );
      return (result as int?) ?? 0;
    } catch (e) {
      print('Arkadaş sayısı çekilirken hata: $e');
      return 0;
    }
  }

  // ──────────────────────── Arkadaşlık İsteği Gönder ────────────────────────

  /// Mevcut kullanıcıdan [addresseeId]'ye arkadaşlık isteği gönderir.
  /// Eski rejected/cancelled kayıt varsa onu günceller, yoksa yeni ekler.
  Future<void> sendFriendRequest(String addresseeId) async {
    final myId = _userId;
    if (myId == null) throw Exception('Oturum bulunamadı.');
    if (myId == addresseeId) throw Exception('Kendinize istek gönderemezsiniz.');

    // Türkçe yorum: Her iki yönde de mevcut kayıt var mı kontrol et.
    // (Daha önce arkadaş olup çıkarılmışsa rejected/cancelled satır kalıyor.)
    final existing = await _client
        .from('friend_requests')
        .select('id, requester_id, addressee_id, status')
        .eq('request_type', 'friend')
        .or('and(requester_id.eq.$myId,addressee_id.eq.$addresseeId),and(requester_id.eq.$addresseeId,addressee_id.eq.$myId)')
        .maybeSingle();

    if (existing != null) {
      final status = (existing['status'] ?? '').toString();
      if (status == 'accepted') {
        throw Exception('Zaten arkadaşsınız.');
      }
      if (status == 'pending') {
        throw Exception('Zaten bekleyen bir istek var.');
      }
      // rejected / cancelled / herhangi başka durum → güncelle
      await _client
          .from('friend_requests')
          .update({
            'requester_id': myId,
            'addressee_id': addresseeId,
            'status': 'pending',
            'is_read': false,
          })
          .eq('id', existing['id']);
      return;
    }

    // Hiç kayıt yok → yeni ekle
    await _client.from('friend_requests').insert({
      'requester_id': myId,
      'addressee_id': addresseeId,
      'status': 'pending',
      'request_type': 'friend',
      'is_read': false,
    });
  }

  /// Mevcut kullanıcı ile [targetUserId] arasında bekleyen (pending) bir
  /// arkadaşlık isteği var mı kontrol eder. Gönderen taraf döner.
  Future<String?> getPendingRequestId(String targetUserId) async {
    final myId = _userId;
    if (myId == null) return null;
    try {
      // Ben gönderdim mi?
      final outgoing = await _client
          .from('friend_requests')
          .select('id')
          .eq('requester_id', myId)
          .eq('addressee_id', targetUserId)
          .eq('status', 'pending')
          .eq('request_type', 'friend')
          .maybeSingle();
      if (outgoing != null) return outgoing['id'].toString();

      // O gönderdi mi?
      final incoming = await _client
          .from('friend_requests')
          .select('id')
          .eq('requester_id', targetUserId)
          .eq('addressee_id', myId)
          .eq('status', 'pending')
          .eq('request_type', 'friend')
          .maybeSingle();
      if (incoming != null) return incoming['id'].toString();

      return null;
    } catch (e) {
      return null;
    }
  }
}
