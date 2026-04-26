import 'package:flutter/material.dart';

/// Takım verilerini temsil eden model sınıfı
class Team {
  final String id;
  final String name;
  final String description;
  final List<String> roles;
  final List<String> skills;
  final int maxMembers;
  int currentMembers;
  final bool isOwner;
  final Color color;
  final DateTime createdAt;

  Team({
    required this.id,
    required this.name,
    required this.description,
    this.roles = const [],
    this.skills = const [],
    this.maxMembers = 5,
    this.currentMembers = 1,
    this.isOwner = true,
    this.color = const Color(0xFF4A7C82),
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Team.fromMap(Map<String, dynamic> map, String currentUserId) {
    int colorIndex = map['id'].toString().hashCode.abs();
    const List<Color> teamColors = [
      Color(0xFF4A7C82),
      Color(0xFF6C63FF),
      Color(0xFF00BFA6),
      Color(0xFFFF6B6B),
      Color(0xFFFFB347),
      Color(0xFF7C4DFF),
      Color(0xFF26A69A),
      Color(0xFFEF5350),
    ];
    return Team(
      id: map['id'].toString(),
      name: map['name'] ?? 'İsimsiz Takım',
      description: map['description'] ?? '',
      roles: List<String>.from(map['required_roles'] ?? []),
      skills: List<String>.from(map['required_skills'] ?? []),
      maxMembers: map['max_members'] ?? 5,
      currentMembers: map['current_members'] ?? 1,
      isOwner: map['admin_id'] == currentUserId,
      color: teamColors[colorIndex % teamColors.length],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
