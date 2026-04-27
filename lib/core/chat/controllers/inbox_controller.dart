import 'dart:async';

import 'package:flutter/foundation.dart';

import '../chat_repository.dart';
import '../models/conversation.dart';

class InboxController extends ChangeNotifier {
  InboxController({required ChatRepository repo}) : _repo = repo;

  final ChatRepository _repo;

  StreamSubscription<List<Conversation>>? _sub;
  List<Conversation> _items = [];
  List<Conversation> get items => List.unmodifiable(_items);

  bool _loading = true;
  bool get loading => _loading;

  Object? _error;
  Object? get error => _error;

  void start() {
    _sub?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();

    _sub = _repo.watchInbox().listen(
      (rows) {
        _items = rows;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e;
        _loading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

