import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session.dart';
import '../models/subject.dart';

class SessionRepository {
  final SupabaseClient _client;

  SessionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Saves a completed Pomodoro session to the `sessions` table.
  Future<int?> saveSession(PomodoroSession session,
      {String? subjectName}) async {
    final userId = _userId;
    if (userId == null) {
      developer.log('No authenticated user — cannot save session',
          name: 'SessionRepository');
      return null;
    }

    try {
      final response = await _client.from('sessions').insert({
        'user_id': userId,
        'subject': subjectName,
        'duration_minutes': session.durationMinutes,
        'completed': true,
      }).select('id').single();

      return response['id'] as int?;
    } catch (e) {
      developer.log('Failed to save session to Supabase: $e',
          name: 'SessionRepository');
      return null;
    }
  }

  /// Fetches sessions for the current user, ordered by newest first.
  Future<List<Map<String, dynamic>>> fetchSessions({
    DateTime? from,
    DateTime? to,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      var query = _client
          .from('sessions')
          .select()
          .eq('user_id', userId);

      if (from != null) {
        query = query.gte('created_at', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('created_at', to.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log('Failed to fetch sessions from Supabase: $e',
          name: 'SessionRepository');
      return [];
    }
  }

  // ── Preferences ──

  Future<Map<String, dynamic>?> fetchPreferences() async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final response = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      developer.log('Failed to fetch preferences: $e',
          name: 'SessionRepository');
      return null;
    }
  }

  Future<void> savePreferences(List<int> presets, int breakDuration) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _client.from('user_preferences').upsert({
        'user_id': userId,
        'presets': presets,
        'break_duration': breakDuration,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      developer.log('Failed to save preferences: $e',
          name: 'SessionRepository');
    }
  }

  // ── Subjects ──

  Future<List<Map<String, dynamic>>> fetchSubjects() async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final response = await _client
          .from('subjects')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log('Failed to fetch subjects: $e',
          name: 'SessionRepository');
      return [];
    }
  }

  Future<void> saveSubject(Subject subject) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _client.from('subjects').upsert({
        'id': subject.id,
        'user_id': userId,
        'name': subject.name,
        'color': subject.color.value,
      });
    } catch (e) {
      developer.log('Failed to save subject: $e',
          name: 'SessionRepository');
    }
  }

  Future<void> deleteSubject(String id) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _client
          .from('subjects')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      developer.log('Failed to delete subject: $e',
          name: 'SessionRepository');
    }
  }
}
