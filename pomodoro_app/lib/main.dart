import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/session_manager.dart';
import 'services/subject_manager.dart';
import 'services/user_profile_manager.dart';
import 'services/audio_service.dart';
import 'services/spotify_service.dart';
import 'screens/home_screen.dart';
import 'screens/profile_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final profileManager = UserProfileManager();
  await profileManager.load();

  runApp(PomodoroCorkboardApp(profileManager: profileManager));
}

class PomodoroCorkboardApp extends StatelessWidget {
  final UserProfileManager profileManager;

  const PomodoroCorkboardApp({super.key, required this.profileManager});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileManager),
        ChangeNotifierProvider(create: (_) => SessionManager()),
        ChangeNotifierProvider(create: (_) => SubjectManager()),
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
        home: const AppEntry(),
      ),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  @override
  void initState() {
    super.initState();
    final profileManager = context.read<UserProfileManager>();
    if (profileManager.currentProfile != null) {
      _wireUpManagers(profileManager.currentUserId!);
    }
  }

  void _wireUpManagers(String userId) {
    final sm = context.read<SessionManager>();
    final sub = context.read<SubjectManager>();
    sm.setUserId(userId);
    sub.setUserId(userId);
    sub.load().then((_) => sm.load());
  }

  void _onProfileSelected() {
    final profileManager = context.read<UserProfileManager>();
    _wireUpManagers(profileManager.currentUserId!);
    setState(() {});
  }

  void _onSwitchProfile() {
    final profileManager = context.read<UserProfileManager>();
    profileManager.clearCurrentProfile();
    context.read<SessionManager>().setUserId(null);
    context.read<SubjectManager>().setUserId(null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profileManager = context.watch<UserProfileManager>();

    if (profileManager.currentProfile == null) {
      return ProfilePicker(onProfileSelected: _onProfileSelected);
    }

    return HomeScreen(onSwitchProfile: _onSwitchProfile);
  }
}
