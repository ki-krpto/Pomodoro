import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/user_profile_manager.dart';

class ProfilePicker extends StatefulWidget {
  final VoidCallback onProfileSelected;

  const ProfilePicker({super.key, required this.onProfileSelected});

  @override
  State<ProfilePicker> createState() => _ProfilePickerState();
}

class _ProfilePickerState extends State<ProfilePicker> {
  @override
  Widget build(BuildContext context) {
    final manager = context.watch<UserProfileManager>();
    final profiles = manager.profiles;

    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                'Focus Board',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A2E27).withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Who\'s focusing?',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF3A2E27).withOpacity(0.4),
                ),
              ),
              const Spacer(),
              if (profiles.isEmpty)
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 48,
                          color: const Color(0xFF3A2E27).withOpacity(0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No profiles yet.\nCreate one to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: const Color(0xFF3A2E27).withOpacity(0.35),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 4,
                  child: ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _buildProfileCard(profiles[i]),
                  ),
                ),
              const SizedBox(height: 16),
              _buildAddButton(),
              const SizedBox(height: 12),
              _buildClearAllButton(),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile) {
    return GestureDetector(
      onTap: () => _showPasswordDialog(profile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDD2C2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: profile.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  profile.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                profile.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A2E27),
                ),
              ),
            ),
            Icon(
              Icons.lock_outline,
              size: 16,
              color: const Color(0xFF3A2E27).withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showCreateDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5A2B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8B5A2B).withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 18,
              color: const Color(0xFF8B5A2B).withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              'New Profile',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B5A2B).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearAllButton() {
    return GestureDetector(
      onTap: _showClearAllDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Clear all data',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF3A2E27).withOpacity(0.25),
          ),
        ),
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This will delete all profiles and sessions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            onPressed: () async {
              final manager = context.read<UserProfileManager>();
              await manager.clearAllData();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog(UserProfile profile) {
    final controller = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(profile.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  errorText: error,
                ),
                onSubmitted: (_) => _attemptLogin(profile, controller, ctx),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _attemptLogin(profile, controller, ctx),
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );
  }

  void _attemptLogin(
      UserProfile profile, TextEditingController controller, BuildContext ctx) {
    final password = controller.text;
    if (context.read<UserProfileManager>().verifyProfilePassword(profile, password)) {
      Navigator.pop(ctx);
      context.read<UserProfileManager>().selectProfile(profile.id);
      widget.onProfileSelected();
    } else {
      controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wrong password'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    Color? pickedColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Password'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _profileColors)
                      GestureDetector(
                        onTap: () => setDialogState(() => pickedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: pickedColor == c
                                ? Border.all(
                                    color: const Color(0xFF3A2E27),
                                    width: 2.5,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final password = passwordController.text;
                if (name.isEmpty || password.isEmpty) return;
                context
                    .read<UserProfileManager>()
                    .createProfile(name, password, color: pickedColor)
                    .then((_) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  widget.onProfileSelected();
                });
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

const List<Color> _profileColors = [
  Color(0xFF8B5A2B),
  Color(0xFF5A8B2B),
  Color(0xFF2B5A8B),
  Color(0xFF8B2B5A),
  Color(0xFF5A2B8B),
  Color(0xFF2B8B5A),
  Color(0xFF8B6B2B),
  Color(0xFF2B6B8B),
];
