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

/// Takım görevini temsil eden model sınıfı
class TeamTask {
  final String id;
  final String teamId;
  final String title;
  final String? description;
  final TaskStatus status;
  final String? assignedTo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // JOIN ile gelen profil bilgileri
  final String? assignedUsername;
  final String? assignedFullName;
  final String? creatorUsername;
  final String? creatorFullName;

  TeamTask({
    required this.id,
    required this.teamId,
    required this.title,
    this.description,
    required this.status,
    this.assignedTo,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.assignedUsername,
    this.assignedFullName,
    this.creatorUsername,
    this.creatorFullName,
  });

  factory TeamTask.fromJson(Map<String, dynamic> json) {
    // assigned_to profil bilgileri (nullable)
    final assignedProfile = json['assigned_profile'] as Map<String, dynamic>?;
    // created_by profil bilgileri
    final creatorProfile = json['creator_profile'] as Map<String, dynamic>?;

    return TeamTask(
      id: json['id'].toString(),
      teamId: json['team_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      status: TaskStatus.fromString(json['status'] ?? 'todo'),
      assignedTo: json['assigned_to']?.toString(),
      createdBy: json['created_by'].toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      assignedUsername: assignedProfile?['username']?.toString(),
      assignedFullName: assignedProfile?['full_name']?.toString(),
      creatorUsername: creatorProfile?['username']?.toString(),
      creatorFullName: creatorProfile?['full_name']?.toString(),
    );
  }

  /// Yeni görev oluşturmak için Map'e çevirir (Supabase insert)
  Map<String, dynamic> toInsertMap() {
    return {
      'team_id': teamId,
      'title': title,
      'description': description,
      'status': status.toDbString(),
      'assigned_to': assignedTo,
      'created_by': createdBy,
    };
  }
}
