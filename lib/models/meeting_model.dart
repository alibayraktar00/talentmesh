import 'user_profile_model.dart';

/// Takım toplantısı verilerini temsil eden model sınıfı.
class Meeting {
  final String id;
  final String teamId;
  final String createdBy;
  final String title;
  final String? description;
  final DateTime meetingDate;
  final String? meetingLink;
  final DateTime createdAt;
  final UserProfile? creatorProfile;

  Meeting({
    required this.id,
    required this.teamId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.meetingDate,
    this.meetingLink,
    required this.createdAt,
    this.creatorProfile,
  });

  /// Supabase'den gelen JSON verisini parse eder.
  /// profiles JOIN verisi varsa creatorProfile olarak set edilir.
  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      meetingDate: DateTime.parse(json['meeting_date'] as String),
      meetingLink: json['meeting_link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      creatorProfile: json['profiles'] != null
          ? UserProfile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  /// INSERT işlemi için Supabase'e gönderilecek JSON payload'u.
  /// id ve created_at DB tarafında otomatik oluşturulur.
  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'meeting_date': meetingDate.toUtc().toIso8601String(),
      'meeting_link': meetingLink,
    };
  }

  /// Toplantının gelecekte mi geçmişte mi olduğunu belirler.
  bool get isUpcoming => meetingDate.isAfter(DateTime.now());
}
