import 'package:flutter/material.dart';
import '../models/meeting_model.dart';
import '../core/services/team_service.dart';

/// Toplantı state yönetimi için ChangeNotifier tabanlı provider.
/// Mevcut TeamProvider deseniyle uyumlu yapıda.
class MeetingProvider extends ChangeNotifier {
  List<Meeting> _meetings = [];
  bool _isLoading = false;
  String _errorMessage = '';

  /// Tüm toplantıların listesi (değiştirilemez kopya)
  List<Meeting> get meetings => List.unmodifiable(_meetings);

  /// Yaklaşan toplantılar (tarih sırasına göre)
  List<Meeting> get upcomingMeetings =>
      _meetings.where((m) => m.isUpcoming).toList();

  /// Geçmiş toplantılar (en yakın geçmiş en üstte)
  List<Meeting> get pastMeetings =>
      _meetings.where((m) => !m.isUpcoming).toList().reversed.toList();

  /// İşlem yükleniyor mu?
  bool get isLoading => _isLoading;

  /// Hata Mesajı
  String get errorMessage => _errorMessage;

  /// Belirli bir takıma ait toplantıları veritabanından çeker.
  Future<void> fetchMeetings(String teamId) async {
    _setLoading(true);
    _errorMessage = '';

    try {
      _meetings = await TeamService().fetchTeamMeetings(teamId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _setLoading(false);
    }
  }

  /// Yeni toplantı oluşturur ve listeyi yeniler.
  Future<void> createMeeting({
    required String teamId,
    required String title,
    String? description,
    required DateTime meetingDate,
    String? meetingLink,
  }) async {
    _setLoading(true);

    try {
      await TeamService().createMeeting(
        teamId: teamId,
        title: title,
        description: description,
        meetingDate: meetingDate,
        meetingLink: meetingLink,
      );

      // Başarılı olduğunda, son verileri tekrar çekerek UI'ı güncelle
      await fetchMeetings(teamId);
    } finally {
      _setLoading(false);
    }
  }

  /// Toplantıyı siler ve listeyi yeniler.
  Future<void> deleteMeeting(String meetingId, String teamId) async {
    try {
      await TeamService().deleteMeeting(meetingId);
      // Silme başarılı olduktan sonra listeyi güncelle
      await fetchMeetings(teamId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
