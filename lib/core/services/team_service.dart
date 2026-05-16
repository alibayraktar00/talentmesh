import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/meeting_model.dart';
import '../../models/task_model.dart';

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

  /// Takımları getirir ve her takımın gerçek üye sayısını team_members'dan hesaplar.
  /// Hem kurucusu olunan hem de üye olarak girilen takımları birleştirerek döner.
  Future<List<Map<String, dynamic>>> fetchTeamsWithMemberCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    // 1. Kurucusu olduğu takımları çek
    final ownedResponse = await _client
        .from('teams')
        .select()
        .eq('admin_id', user.id)
        .order('created_at', ascending: false);
    final ownedTeams = List<Map<String, dynamic>>.from(ownedResponse);
    final ownedTeamIds = ownedTeams.map((t) => t['id'].toString()).toSet();

    // 2. Üye olarak girilen takımların ID'lerini team_members'dan çek
    final memberRowsResponse = await _client
        .from('team_members')
        .select('team_id')
        .eq('user_id', user.id);

    final joinedTeamIds = List<Map<String, dynamic>>.from(memberRowsResponse)
        .map((r) => r['team_id'].toString())
        .where((id) => !ownedTeamIds.contains(id)) // Kurucu olduğu takımları tekrar ekleme
        .toList();

    // 3. Üye olunan takımların detaylarını çek
    List<Map<String, dynamic>> joinedTeams = [];
    if (joinedTeamIds.isNotEmpty) {
      final joinedResponse = await _client
          .from('teams')
          .select()
          .inFilter('id', joinedTeamIds);
      joinedTeams = List<Map<String, dynamic>>.from(joinedResponse);
    }

    // 4. İkisini birleştir — kurucusu olunanlar önce
    final allTeams = [...ownedTeams, ...joinedTeams];
    if (allTeams.isEmpty) return [];

    // 5. Tüm takımların üye sayılarını çek
    final allTeamIds = allTeams.map((t) => t['id'].toString()).toList();
    final membersResponse = await _client
        .from('team_members')
        .select('team_id')
        .inFilter('team_id', allTeamIds);

    // 6. Her takım için üye sayısını hesapla
    final memberCountMap = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(membersResponse)) {
      final tid = row['team_id'].toString();
      memberCountMap[tid] = (memberCountMap[tid] ?? 0) + 1;
    }

    // 7. Takım verilerine current_members ekle
    // Kurucu hiçbir zaman team_members tablosuna eklenmez → her zaman +1
    return allTeams.map((t) {
      final tid = t['id'].toString();
      return {
        ...t,
        'current_members': (memberCountMap[tid] ?? 0) + 1,
      };
    }).toList();
  }

  /// Mevcut oturum açmış kullanıcının kimliği.
  String? get currentUserId => _client.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════════════════
  // TAKIM İSTEKLERİ İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════════

  /// Takıma katılma isteği gönderir
  Future<void> sendJoinRequest(String teamId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');
      }

      await _client.from('team_requests').insert({
        'team_id': teamId,
        'user_id': user.id,
        'status': 'pending',
      });
    } catch (e) {
      print('İstek gönderilirken hata: $e');
      rethrow;
    }
  }

  /// Takımın gelen katılma isteklerini çeker
  Future<List<Map<String, dynamic>>> getIncomingRequests(String teamId) async {
    try {
      final response = await _client
          .from('team_requests')
          .select('''
            *,
            profiles:user_id (
              id,
              username,
              full_name,
              avatar_url,
              department
            )
          ''')
          .eq('team_id', teamId)
          .eq('status', 'pending');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Gelen istekleri çekerken hata: $e');
      rethrow;
    }
  }

  /// Katılma isteğini kabul eder (Kapasite kontrolü yapar)
  Future<void> acceptJoinRequest(String requestId, String teamId, String userId, int maxMembers) async {
    try {
      // 1. Kapasite kontrolü
      final membersResponse = await _client
          .from('team_members')
          .select('id')
          .eq('team_id', teamId);
          
      final currentMembersCount = (membersResponse as List).length;

      if (currentMembersCount >= maxMembers) {
        throw Exception('Takım kapasitesi dolu.');
      }

      // 2. İsteği onaylandı olarak işaretle
      await _client
          .from('team_requests')
          .update({'status': 'approved'})
          .eq('id', requestId);

      // 3. Kullanıcıyı takıma ekle
      await _client.from('team_members').insert({
        'team_id': teamId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      print('İstek kabul edilirken hata: $e');
      rethrow;
    }
  }

  /// Katılma isteğini reddeder
  Future<void> rejectJoinRequest(String requestId) async {
    try {
      await _client
          .from('team_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);
    } catch (e) {
      print('İstek reddedilirken hata: $e');
      rethrow;
    }
  }

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

  // ═══════════════════════════════════════════════════════════════
  // AKILLI EŞLEŞTİRME (SMART MATCHMAKING) İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════════

  /// Kullanıcının yetenekleriyle aranan rolleri/yetenekleri örtüşen takımları getirir.
  Future<List<Map<String, dynamic>>> fetchSmartMatches() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      print('[SmartMatch] Kullanıcı oturumu bulunamadı.');
      return [];
    }

    try {
      // 1. Kullanıcının profil bilgilerini çek
      final profileResponse = await _client
          .from('profiles')
          .select('open_to_work, skills')
          .eq('id', user.id)
          .maybeSingle();

      print('[SmartMatch] Profil verisi: $profileResponse');

      if (profileResponse == null) {
        print('[SmartMatch] Profil bulunamadı.');
        return [];
      }

      final userSkills = List<String>.from(profileResponse['skills'] ?? []);

      print('[SmartMatch] Kullanıcı yetenekleri: $userSkills');

      if (userSkills.isEmpty) {
        print('[SmartMatch] Yetenek listesi boş, çıkılıyor.');
        return [];
      }


      // 2. Kendi olmadığımız tüm takımları çek
      final matchesResponse = await _client
          .from('teams')
          .select()
          .neq('admin_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final allTeams = List<Map<String, dynamic>>.from(matchesResponse);
      print('[SmartMatch] Toplam bulunan takım sayısı: ${allTeams.length}');

      for (final team in allTeams) {
        print('[SmartMatch] Takım: ${team['name']} | skills: ${team['required_skills']} | roles: ${team['required_roles']}');
      }

      final userSkillsLower = userSkills.map((e) => e.toLowerCase().trim()).toSet();

      final filteredTeams = allTeams.where((team) {
        final teamSkills = List<String>.from(team['required_skills'] ?? []);
        final teamSkillsLower = teamSkills.map((e) => e.toLowerCase().trim()).toSet();

        final bool hasSkillMatch = teamSkillsLower.intersection(userSkillsLower).isNotEmpty;

        print('[SmartMatch] ${team['name']} -> skillMatch: $hasSkillMatch | team: $teamSkillsLower | user: $userSkillsLower');

        return hasSkillMatch;
      }).take(5).toList();


      print('[SmartMatch] Eşleşen takım sayısı: ${filteredTeams.length}');
      return filteredTeams;
    } catch (e) {
      print('[SmartMatch] HATA: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GÖREV (TASK) İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════════

  /// Takıma ait görevleri profil bilgileriyle birlikte çeker.
  Future<List<TeamTask>> fetchTeamTasks(String teamId) async {
    try {
      final response = await _client
          .from('team_tasks')
          .select('''
            *,
            assignees:team_task_assignees (
              user_id,
              profiles:user_id (
                id,
                username,
                full_name,
                avatar_url
              )
            ),
            creator_profile:created_by (
              id,
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('team_id', teamId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response)
          .map((item) => TeamTask.fromJson(item))
          .toList();
    } on PostgrestException catch (e) {
      print('Görevleri çekerken (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Görevleri çekerken hata: $e');
      rethrow;
    }
  }

  /// Yeni bir görev oluşturur ve görevlileri atar.
  Future<void> createTask({
    required String teamId,
    required String title,
    String? description,
    DateTime? dueDate,
    List<Map<String, dynamic>> subtasks = const [],
    List<String> assignedTo = const [],
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Oturum açmış bir kullanıcı bulunamadı.');
      }

      // 1. Görevi oluştur ve ID'sini al
      final taskResponse = await _client.from('team_tasks').insert({
        'team_id': teamId,
        'title': title,
        'description': description,
        'due_date': dueDate?.toIso8601String(),
        'subtasks': subtasks,
        'status': 'todo',
        'created_by': user.id,
      }).select('id').single();

      final taskId = taskResponse['id'].toString();

      // 2. Görevlileri junction tablosuna ekle
      if (assignedTo.isNotEmpty) {
        final assigneeRows = assignedTo.map((userId) => {
          'task_id': taskId,
          'user_id': userId,
        }).toList();
        await _client.from('team_task_assignees').insert(assigneeRows);
      }

      print('Görev oluşturuldu: $title (${assignedTo.length} kişi atandı)');
    } on PostgrestException catch (e) {
      print('Görev oluşturma (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Görev oluşturma hatası: $e');
      rethrow;
    }
  }

  /// Görev durumunu günceller (Kanban geçişleri).
  Future<void> updateTaskStatus(String taskId, TaskStatus newStatus) async {
    try {
      await _client
          .from('team_tasks')
          .update({'status': newStatus.toDbString()})
          .eq('id', taskId);
      print('Görev durumu güncellendi: $taskId -> ${newStatus.toDbString()}');
    } on PostgrestException catch (e) {
      print('Görev durumu güncelleme (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Görev durumu güncelleme hatası: $e');
      rethrow;
    }
  }

  /// Görev detaylarını günceller.
  Future<void> updateTask({
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    List<Map<String, dynamic>>? subtasks,
    String? assignedTo,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (dueDate != null) updates['due_date'] = dueDate.toIso8601String();
      if (subtasks != null) updates['subtasks'] = subtasks;
      if (assignedTo != null) updates['assigned_to'] = assignedTo;

      if (updates.isNotEmpty) {
        await _client.from('team_tasks').update(updates).eq('id', taskId);
      }
      print('Görev güncellendi: $taskId');
    } on PostgrestException catch (e) {
      print('Görev güncelleme (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Görev güncelleme hatası: $e');
      rethrow;
    }
  }

  /// Görevi siler.
  Future<void> deleteTask(String taskId) async {
    try {
      await _client.from('team_tasks').delete().eq('id', taskId);
      print('Görev silindi: $taskId');
    } on PostgrestException catch (e) {
      print('Görev silme (Postgrest) hatası: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Görev silme hatası: $e');
      rethrow;
    }
  }
}
