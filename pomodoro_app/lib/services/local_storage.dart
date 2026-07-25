import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import '../models/subject.dart';

class LocalStorage {
  static String _key(String userId, String suffix) => '${userId}_$suffix';

  static const _sessionSuffix = 'pomodoro_sessions_v1';
  static const _subjectSuffix = 'subjects_v1';
  static const _presetsSuffix = 'timer_presets_v1';
  static const _breakDurationSuffix = 'break_duration_v1';
  static const _longBreakDurationSuffix = 'long_break_duration_v1';
  static const _pomodorosBeforeLongBreakSuffix =
      'pomodoros_before_long_break_v1';

  // ── Sessions ──

  Future<List<PomodoroSession>> loadSessions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, _sessionSuffix));
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => PomodoroSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSessions(String userId, List<PomodoroSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_key(userId, _sessionSuffix), raw);
  }

  // ── Subjects ──

  Future<List<Subject>> loadSubjects(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, _subjectSuffix));
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Subject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSubjects(String userId, List<Subject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(subjects.map((s) => s.toJson()).toList());
    await prefs.setString(_key(userId, _subjectSuffix), raw);
  }

  // ── Preferences ──

  static const List<int> defaultPresets = [25, 45, 60];

  Future<List<int>> loadPresets(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, _presetsSuffix));
    if (raw == null || raw.isEmpty) return defaultPresets;
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<int>();
  }

  Future<void> savePresets(String userId, List<int> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(presets);
    await prefs.setString(_key(userId, _presetsSuffix), raw);
  }

  static const int defaultBreakDuration = 5;
  static const int defaultLongBreakDuration = 15;
  static const int defaultPomodorosBeforeLongBreak = 4;

  Future<int> loadBreakDuration(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(userId, _breakDurationSuffix)) ??
        defaultBreakDuration;
  }

  Future<void> saveBreakDuration(String userId, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(userId, _breakDurationSuffix), minutes);
  }

  Future<int> loadLongBreakDuration(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(userId, _longBreakDurationSuffix)) ??
        defaultLongBreakDuration;
  }

  Future<void> saveLongBreakDuration(String userId, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(userId, _longBreakDurationSuffix), minutes);
  }

  Future<int> loadPomodorosBeforeLongBreak(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(userId, _pomodorosBeforeLongBreakSuffix)) ??
        defaultPomodorosBeforeLongBreak;
  }

  Future<void> savePomodorosBeforeLongBreak(String userId, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(userId, _pomodorosBeforeLongBreakSuffix), count);
  }

  // ── Cleanup ──

  Future<void> clearUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      _key(userId, _sessionSuffix),
      _key(userId, _subjectSuffix),
      _key(userId, _presetsSuffix),
      _key(userId, _breakDurationSuffix),
      _key(userId, _longBreakDurationSuffix),
      _key(userId, _pomodorosBeforeLongBreakSuffix),
    ];
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
