import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserProfileManager extends ChangeNotifier {
  static const _profilesKey = 'user_profiles_v1';
  static const _currentProfileKey = 'current_profile_id_v1';

  final List<UserProfile> _profiles = [];
  UserProfile? _currentProfile;

  List<UserProfile> get profiles => List.unmodifiable(_profiles);
  UserProfile? get currentProfile => _currentProfile;
  String? get currentUserId => _currentProfile?.id;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _profiles
        ..clear()
        ..addAll(decoded.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)));
    }
    final currentId = prefs.getString(_currentProfileKey);
    if (currentId != null) {
      _currentProfile = _profiles.where((p) => p.id == currentId).firstOrNull;
    }
    notifyListeners();
  }

  Future<UserProfile> createProfile(String name, {Color? color}) async {
    final profile = UserProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      color: color ?? UserProfile.generateColor(name),
    );
    _profiles.add(profile);
    _currentProfile = profile;
    await _save();
    notifyListeners();
    return profile;
  }

  Future<void> selectProfile(String id) async {
    _currentProfile = _profiles.where((p) => p.id == id).firstOrNull;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentProfileKey, id);
    notifyListeners();
  }

  void clearCurrentProfile() {
    _currentProfile = null;
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    if (_currentProfile?.id == id) {
      _currentProfile = _profiles.isNotEmpty ? _profiles.first : null;
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, raw);
    if (_currentProfile != null) {
      await prefs.setString(_currentProfileKey, _currentProfile!.id);
    }
  }
}
