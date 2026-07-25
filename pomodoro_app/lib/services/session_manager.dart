import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../utils/note_placement.dart';
import 'local_storage.dart';

class SessionManager extends ChangeNotifier {
  final LocalStorage _storage = LocalStorage();
  final List<PomodoroSession> _sessions = [];
  String? _userId;

  static const int stickyNoteColorCount = 5;

  List<PomodoroSession> get sessions => List.unmodifiable(_sessions);

  bool _loaded = false;
  bool get loaded => _loaded;

  void setUserId(String? userId) {
    _userId = userId;
  }

  Future<void> load() async {
    final uid = _userId;
    if (uid == null) {
      _sessions.clear();
      _loaded = true;
      notifyListeners();
      return;
    }
    final loadedSessions = await _storage.loadSessions(uid);
    _sessions
      ..clear()
      ..addAll(loadedSessions);
    _loaded = true;
    notifyListeners();
  }

  Future<PomodoroSession> completeSession(int durationMinutes,
      {String? subjectId}) async {
    final placement = NotePlacement.generate(colorCount: stickyNoteColorCount);
    final session = PomodoroSession(
      durationMinutes: durationMinutes,
      completedAt: DateTime.now(),
      dx: placement.dx,
      dy: placement.dy,
      rotationDeg: placement.rotationDeg,
      colorIndex: placement.colorIndex,
      subjectId: subjectId,
    );

    _sessions.add(session);
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSessions(uid, _sessions);
    }
    return session;
  }

  Future<void> clearAllSessions() async {
    _sessions.clear();
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSessions(uid, _sessions);
    }
  }

  Future<void> debugBatchSessions(int count,
      {List<int>? durations, String? subjectId}) async {
    final pool = durations ?? [25, 45, 60];
    for (var i = 0; i < count; i++) {
      final placement = NotePlacement.generate(colorCount: stickyNoteColorCount);
      final minutes = pool[i % pool.length];
      _sessions.add(PomodoroSession(
        durationMinutes: minutes,
        completedAt: DateTime.now().subtract(Duration(hours: count - i)),
        dx: placement.dx,
        dy: placement.dy,
        rotationDeg: placement.rotationDeg,
        colorIndex: placement.colorIndex,
        subjectId: subjectId,
      ));
    }
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSessions(uid, _sessions);
    }
  }
}
