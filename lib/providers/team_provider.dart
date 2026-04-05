import 'package:flutter/material.dart';
import '../models/team_model.dart';

/// Global state yönetimi için ChangeNotifier tabanlı provider.
/// Oluşturulan takımları tutar ve widget ağacına değişiklikleri bildirir.
class TeamProvider extends ChangeNotifier {
  final List<Team> _teams = [];

  /// Tüm takımların listesi (değiştirilemez kopya)
  List<Team> get teams => List.unmodifiable(_teams);

  /// Takım sayısı
  int get teamCount => _teams.length;

  /// Yeni takım ekle ve dinleyicileri bilgilendir
  void addTeam(Team team) {
    _teams.insert(0, team); // En yeni en üstte
    notifyListeners();
  }

  /// Takım sil
  void removeTeam(String id) {
    _teams.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
