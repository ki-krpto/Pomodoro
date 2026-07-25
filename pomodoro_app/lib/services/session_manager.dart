import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../repositories/session_repository.dart';
import '../utils/note_placement.dart';
import 'local_storage.dart';
import 'subject_manager.dart';

/// Single source of truth for completed Pomodoro sessions.
/// Owns the in-memory list, talks to LocalStorage for persistence,
/// and notifies the UI (Timer, CorkBoard) when it changes.
class SessionManager extends ChangeNotifier {
  final LocalStorage _storage = LocalStorage();
  final List<PomodoroSession> _sessions = [];
  final SessionRepository? _repository;
  SubjectManager? _subjectManager;
  String? _userId;

  /// Must match the length of the palette in widgets/sticky_note.dart.
  static const int stickyNoteColorCount = 5;

  List<PomodoroSession> get sessions => List.unmodifiable(_sessions);

  bool _loaded = false;
  bool get loaded => _loaded;

  SessionManager({SessionRepository? repository}) : _repository = repository;

  /// Called after SubjectManager is available, so we can resolve subject names.
  void attachSubjectManager(SubjectManager sm) {
    _subjectManager = sm;
  }

  /// Sets the current user ID for scoped local storage.
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Load sessions from local storage (used on app start before auth).
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

  /// Fetch sessions from Supabase for the logged-in user, replacing local data.
  Future<void> loadFromCloud() async {
    if (_repository == null) return;

    final cloudData = await _repository!.fetchSessions();
    final cloudSessions = cloudData.map((row) {
      // Prefer subject_id (new schema), fall back to subject name resolution
      String? resolvedSubjectId = row['subject_id'] as String?;
      if (resolvedSubjectId == null) {
        final subjectName = row['subject'] as String?;
        if (subjectName != null && _subjectManager != null) {
          resolvedSubjectId =
              _subjectManager!.getSubjectByIdentifier(subjectName)?.id;
        }
      }

      // Read visual properties from the row, fall back to 0 for old rows
      return PomodoroSession(
        durationMinutes: row['duration_minutes'] as int,
        completedAt: DateTime.parse(row['created_at'] as String).toLocal(),
        dx: (row['dx'] as num?)?.toDouble() ?? 0,
        dy: (row['dy'] as num?)?.toDouble() ?? 0,
        rotationDeg: (row['rotation_deg'] as num?)?.toDouble() ?? 0,
        colorIndex: row['color_index'] as int? ?? 0,
        subjectId: resolvedSubjectId,
      );
    }).toList();

    _sessions
      ..clear()
      ..addAll(cloudSessions);
    _loaded = true;
    notifyListeners();

    // Also persist to local storage as a cache
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSessions(uid, _sessions);
    }
  }

  /// Clear in-memory sessions (used on logout).
  void clear() {
    _sessions.clear();
    notifyListeners();
  }

  /// Creates a new session, gives it a permanent placement, appends it,
  /// persists it, and notifies listeners — one sticky note, once.
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

    // Save to Supabase (fire-and-forget — local persistence always wins)
    if (_repository != null) {
      final subjectName = subjectId != null && _subjectManager != null
          ? _subjectManager!.getSubject(subjectId)?.name
          : null;
      _repository!
          .saveSession(session, subjectName: subjectName)
          .then((id) {
        if (id != null) {
          developer.log('Session saved to Supabase with id=$id',
              name: 'SessionManager');
        }
      }).catchError((e) {
        developer.log('Supabase save failed (non-blocking): $e',
            name: 'SessionManager');
      });
    }

    return session;
  }

  /// Fetches all sessions from Supabase. Useful for cloud history / sync.
  Future<List<Map<String, dynamic>>> fetchSessionsFromCloud({
    DateTime? from,
    DateTime? to,
  }) async {
    if (_repository == null) return [];
    return _repository!.fetchSessions(from: from, to: to);
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
