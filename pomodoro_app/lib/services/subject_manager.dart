import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../repositories/session_repository.dart';
import 'local_storage.dart';

class SubjectManager extends ChangeNotifier {
  final LocalStorage _storage = LocalStorage();
  final List<Subject> _subjects = [];
  SessionRepository? _repository;
  String? _userId;

  List<Subject> get subjects => List.unmodifiable(_subjects);

  bool _loaded = false;
  bool get loaded => _loaded;

  void attachRepository(SessionRepository repository) {
    _repository = repository;
  }

  /// Sets the current user ID for scoped local storage.
  void setUserId(String? userId) {
    _userId = userId;
  }

  Subject? getSubjectByIdentifier(String? identifier) {
    if (identifier == null) return null;
    try {
      return _subjects.firstWhere((s) => s.id == identifier || s.name == identifier);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final uid = _userId;
    if (uid == null) {
      _subjects.clear();
      _loaded = true;
      notifyListeners();
      return;
    }
    final loaded = await _storage.loadSubjects(uid);
    _subjects
      ..clear()
      ..addAll(loaded);
    _loaded = true;
    notifyListeners();
  }

  Future<void> loadFromCloud() async {
    if (_repository == null) return load();

    try {
      final cloudData = await _repository!.fetchSubjects();
      if (cloudData.isNotEmpty) {
        final cloudSubjects = cloudData.map((row) {
          return Subject(
            id: row['id'] as String,
            name: row['name'] as String,
            color: Color(row['color'] as int),
          );
        }).toList();
        _subjects
          ..clear()
          ..addAll(cloudSubjects);
      }
    } catch (e) {
      debugPrint('SubjectManager: cloud load failed, using local: $e');
    }

    _loaded = true;
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSubjects(uid, _subjects);
    }
  }

  Future<Subject> createSubject(String name, {Color? color}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final subject = Subject(
      id: id,
      name: name,
      color: color ?? Subject.generatePastelColor(name),
    );
    _subjects.add(subject);
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSubjects(uid, _subjects);
    }
    _repository?.saveSubject(subject);
    return subject;
  }

  Future<void> renameSubject(String id, String newName) async {
    final idx = _subjects.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    _subjects[idx].name = newName;
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSubjects(uid, _subjects);
    }
    _repository?.saveSubject(_subjects[idx]);
  }

  Future<void> deleteSubject(String id) async {
    _subjects.removeWhere((s) => s.id == id);
    notifyListeners();
    final uid = _userId;
    if (uid != null) {
      await _storage.saveSubjects(uid, _subjects);
    }
    _repository?.deleteSubject(id);
  }

  Subject? getSubject(String? id) {
    if (id == null) return null;
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
