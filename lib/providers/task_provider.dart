import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../core/services/team_service.dart';

/// Takım görevlerini yöneten ve UI'a bildiren state yöneticisi.
class TaskProvider extends ChangeNotifier {
  final TeamService _teamService = TeamService();

  List<TeamTask> _tasks = [];
  bool _isLoading = false;
  String? _error;

  // ────────── GETTERS ──────────

  List<TeamTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// "Yapılacak" görevleri
  List<TeamTask> get todoTasks =>
      _tasks.where((t) => t.status == TaskStatus.todo).toList();

  /// "Devam Eden" görevleri
  List<TeamTask> get inProgressTasks =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).toList();

  /// "Tamamlanan" görevleri
  List<TeamTask> get doneTasks =>
      _tasks.where((t) => t.status == TaskStatus.done).toList();

  /// İlerleme oranı (0.0 - 1.0)
  double get progress {
    if (_tasks.isEmpty) return 0.0;
    return doneTasks.length / _tasks.length;
  }

  /// İlerleme yüzdesi (0 - 100)
  int get progressPercent => (progress * 100).round();

  // ────────── FETCH ──────────

  /// Takıma ait görevleri Supabase'den çeker.
  Future<void> fetchTasks(String teamId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _teamService.fetchTeamTasks(teamId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ────────── CREATE ──────────

  /// Yeni görev oluşturur ve listeyi yeniler.
  Future<void> createTask({
    required String teamId,
    required String title,
    String? description,
    String? assignedTo,
  }) async {
    try {
      await _teamService.createTask(
        teamId: teamId,
        title: title,
        description: description,
        assignedTo: assignedTo,
      );
      await fetchTasks(teamId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ────────── UPDATE STATUS ──────────

  /// Görev durumunu günceller (Kanban sütunları arası geçiş).
  Future<void> updateTaskStatus({
    required String taskId,
    required String teamId,
    required TaskStatus newStatus,
  }) async {
    try {
      await _teamService.updateTaskStatus(taskId, newStatus);
      await fetchTasks(teamId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ────────── UPDATE TASK ──────────

  /// Görev detaylarını günceller.
  Future<void> updateTask({
    required String taskId,
    required String teamId,
    required String title,
    String? description,
    String? assignedTo,
  }) async {
    try {
      await _teamService.updateTask(
        taskId: taskId,
        title: title,
        description: description,
        assignedTo: assignedTo,
      );
      await fetchTasks(teamId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ────────── DELETE ──────────

  /// Görevi siler ve listeyi yeniler.
  Future<void> deleteTask({
    required String taskId,
    required String teamId,
  }) async {
    try {
      await _teamService.deleteTask(taskId);
      await fetchTasks(teamId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
