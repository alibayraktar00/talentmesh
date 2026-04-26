/// Kullanıcı profil verilerini temsil eden model sınıfı
class UserProfile {
  final String id;
  final String username;
  final String fullName;

  UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Bilinmeyen Kullanıcı',
      fullName: json['full_name'] as String? ?? '',
    );
  }
}
