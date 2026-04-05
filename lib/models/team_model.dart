import 'package:flutter/material.dart';

/// Takım verilerini temsil eden model sınıfı
class Team {
  final String id;
  final String name;
  final String description;
  final List<String> roles;
  final List<String> skills;
  final int maxMembers;
  final int currentMembers;
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
}
