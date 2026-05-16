import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/services/notification_service.dart';

/// Okunmamış bildirim sayacını realtime dinleyen ChangeNotifier.
class NotificationProvider extends ChangeNotifier {
  final NotificationService service = NotificationService();
  StreamSubscription<int>? _unreadSub;
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  void startListening() {
    _unreadSub?.cancel();
    _unreadSub = service.watchUnreadCount().listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }
}
