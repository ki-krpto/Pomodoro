import 'package:flutter/material.dart';
import '../models/subject.dart';
import 'local_storage.dart';

class SubjectManager extends ChangeNotifier {
  final LocalStorage _storage = LocalStorage();
  final List<Subject> _subjects = [];

  List<Subject> get subjects => List.unmodifiable(_subjects);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final loaded = await _storage.loadSubjects();
    _subjects
      ..clear()
      ..addAll(loaded);
    _loaded = true;
    notifyListeners();
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
    await _storage.saveSubjects(_subjects);
    return subject;
  }

  Future<void> renameSubject(String id, String newName) async {
    final idx = _subjects.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    _subjects[idx].name = newName;
    notifyListeners();
    await _storage.saveSubjects(_subjects);
  }

  Future<void> deleteSubject(String id) async {
    _subjects.removeWhere((s) => s.id == id);
    notifyListeners();
    await _storage.saveSubjects(_subjects);
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
