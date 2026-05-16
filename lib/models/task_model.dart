/// Görev durumunu temsil eden enum
enum TaskStatus {
  todo,
  inProgress,
  done;

  /// Supabase'deki string değerini enum'a çevirir
  static TaskStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      case 'todo':
      default:
        return TaskStatus.todo;
    }
  }

  /// Enum'u Supabase'e kaydedilecek string değere çevirir
  String toDbString() {
    switch (this) {
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.done:
        return 'done';
    }
  }

  /// Kullanıcı arayüzünde gösterilecek Türkçe etiket
  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'Yapılacak';
      case TaskStatus.inProgress:
        return 'Devam Eden';
      case TaskStatus.done:
        return 'Tamamlandı';
    }
  }
}

/// Göreve atanan kişiyi temsil eden model
class TaskAssignee {
  final String userId;
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  TaskAssignee({
    required this.userId,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return TaskAssignee(
      userId: json['user_id']?.toString() ?? '',
      username: profiles?['username']?.toString(),
      fullName: profiles?['full_name']?.toString(),
      avatarUrl: profiles?['avatar_url']?.toString(),
    );
  }
}

/// Takım görevini temsil eden model sınıfı
class TeamTask {
  final String id;
  final String teamId;
  final String title;
  final String? description;
  final TaskStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? dueDate;
  final List<Map<String, dynamic>> subtasks;

  // Birden fazla görevli
  final List<TaskAssignee> assignees;

  // Oluşturan kişi profil bilgileri
  final String? creatorUsername;
  final String? creatorFullName;

  TeamTask({
    required this.id,
    required this.teamId,
    required this.title,
    this.description,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.dueDate,
    this.subtasks = const [],
    this.assignees = const [],
    this.creatorUsername,
    this.creatorFullName,
  });

  factory TeamTask.fromJson(Map<String, dynamic> json) {
    // created_by profil bilgileri
    final creatorProfile = json['creator_profile'] as Map<String, dynamic>?;

    // Birden fazla görevli (junction table)
    final assigneesRaw = json['assignees'] as List<dynamic>? ?? [];
    final assignees = assigneesRaw
        .map((a) => TaskAssignee.fromJson(a as Map<String, dynamic>))
        .toList();

    // Alt görevler (subtasks) jsonb alanı
    final subtasksRaw = json['subtasks'] as List<dynamic>? ?? [];
    final subtasksList = subtasksRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return TeamTask(
      id: json['id'].toString(),
      teamId: json['team_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      status: TaskStatus.fromString(json['status'] ?? 'todo'),
      createdBy: json['created_by'].toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      subtasks: subtasksList,
      assignees: assignees,
      creatorUsername: creatorProfile?['username']?.toString(),
      creatorFullName: creatorProfile?['full_name']?.toString(),
    );
  }
}
