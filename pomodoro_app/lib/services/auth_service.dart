import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client;
  late final Stream<AuthState> _authStateStream;

  User? get user => _client.auth.currentUser;
  bool get isLoggedIn => user != null;
  Stream<AuthState> get authStateStream => _authStateStream;

  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    _authStateStream = _client.auth.onAuthStateChange;
    _authStateStream.listen((data) {
      notifyListeners();
    });
  }

  Future<String?> signUp(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        notifyListeners();
        return null;
      }
      return 'Sign up failed';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      developer.log('Sign up error: $e', name: 'AuthService');
      return 'An unexpected error occurred';
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        notifyListeners();
        return null;
      }
      return 'Sign in failed';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      developer.log('Sign in error: $e', name: 'AuthService');
      return 'An unexpected error occurred';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    notifyListeners();
  }
}
