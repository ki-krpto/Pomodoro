import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';
import '../models/subject.dart';

class LocalStorage {
  static String _key(String userId, String suffix) => '${userId}_$suffix';

  static const _sessionSuffix = 'pomodoro_sessions_v1';
  static const _subjectSuffix = 'subjects_v1';

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

  // ── Preferences (device-wide, shared across profiles) ──

  static const _presetsKey = 'timer_presets_v1';
  static const _breakDurationKey = 'break_duration_v1';
  static const _longBreakDurationKey = 'long_break_duration_v1';
  static const _pomodorosBeforeLongBreakKey = 'pomodoros_before_long_break_v1';

  static const List<int> defaultPresets = [25, 45, 60];
  static const int defaultBreakDuration = 5;
  static const int defaultLongBreakDuration = 15;
  static const int defaultPomodorosBeforeLongBreak = 4;

  Future<List<int>> loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetsKey);
    if (raw == null || raw.isEmpty) return defaultPresets;
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<int>();
  }

  Future<void> savePresets(List<int> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(presets);
    await prefs.setString(_presetsKey, raw);
  }

  Future<int> loadBreakDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_breakDurationKey) ?? defaultBreakDuration;
  }

  Future<void> saveBreakDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_breakDurationKey, minutes);
  }

  Future<int> loadLongBreakDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_longBreakDurationKey) ?? defaultLongBreakDuration;
  }

  Future<void> saveLongBreakDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_longBreakDurationKey, minutes);
  }

  Future<int> loadPomodorosBeforeLongBreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pomodorosBeforeLongBreakKey) ??
        defaultPomodorosBeforeLongBreak;
  }

  Future<void> savePomodorosBeforeLongBreak(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pomodorosBeforeLongBreakKey, count);
  }
}
