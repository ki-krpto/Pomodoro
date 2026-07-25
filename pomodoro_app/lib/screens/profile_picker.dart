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
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile) {
    return GestureDetector(
      onTap: () async {
        await context.read<UserProfileManager>().selectProfile(profile.id);
        widget.onProfileSelected();
      },
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
              Icons.chevron_right,
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

  void _showCreateDialog() {
    final controller = TextEditingController();
    Color? pickedColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Name'),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                context
                    .read<UserProfileManager>()
                    .createProfile(name, color: pickedColor)
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
