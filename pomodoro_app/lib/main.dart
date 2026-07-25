import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import 'config/env.dart';
import 'repositories/session_repository.dart';
import 'services/auth_service.dart';
import 'services/local_storage.dart';
import 'services/session_manager.dart';
import 'services/subject_manager.dart';
import 'services/audio_service.dart';
import 'services/spotify_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const PomodoroCorkboardApp());
}

class PomodoroCorkboardApp extends StatelessWidget {
  const PomodoroCorkboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = SessionRepository();

    return MultiProvider(
      providers: [
        Provider.value(value: repository),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
            create: (_) => SessionManager(repository: repository)),
        ChangeNotifierProvider(
            create: (_) => SubjectManager()..attachRepository(repository)),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => SpotifyService()),
      ],
      child: MaterialApp(
        title: 'Focus Board',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF4EFE6),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B5A2B),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.nunitoTextTheme(),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Routes to AuthScreen or HomeScreen based on auth state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _localStorage = LocalStorage();
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    auth.addListener(_onAuthChanged);

    // Handle Spotify OAuth redirect if returning from auth
    final spotify = context.read<SpotifyService>();
    spotify.handleRedirect();

    // If already logged in, wire up user IDs and load from cloud
    if (auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupUser(auth.user?.id);
      });
    }
  }

  @override
  void dispose() {
    context.read<AuthService>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _setupUser(String? userId) {
    final sm = context.read<SessionManager>();
    final sub = context.read<SubjectManager>();
    sm.attachSubjectManager(sub);
    sm.setUserId(userId);
    sub.setUserId(userId);
    _lastUserId = userId;
    sub.loadFromCloud().then((_) => sm.loadFromCloud());
  }

  void _onAuthChanged() {
    final auth = context.read<AuthService>();
    final sm = context.read<SessionManager>();
    final sub = context.read<SubjectManager>();

    if (auth.isLoggedIn) {
      _setupUser(auth.user?.id);
    } else {
      // Clear old user's cached SharedPreferences data
      final oldUserId = _lastUserId;
      if (oldUserId != null) {
        _localStorage.clearUser(oldUserId);
      }
      sm.setUserId(null);
      sm.clear();
      sub.setUserId(null);
      sub.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isLoggedIn) {
      return const HomeScreen();
    }
    return const AuthScreen();
  }
}
