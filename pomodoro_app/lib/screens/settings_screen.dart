import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/session_repository.dart';
import '../services/auth_service.dart';
import '../services/local_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalStorage _storage = LocalStorage();

  List<int> _presets = LocalStorage.defaultPresets;
  int _breakMinutes = LocalStorage.defaultBreakDuration;
  int _longBreakMinutes = LocalStorage.defaultLongBreakDuration;
  int _pomodorosBeforeLongBreak = LocalStorage.defaultPomodorosBeforeLongBreak;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String? get _userId => context.read<AuthService>().user?.id;

  Future<void> _loadSettings() async {
    final uid = _userId;
    final presets = await _storage.loadPresets(uid ?? '');
    final breakDuration = await _storage.loadBreakDuration(uid ?? '');
    final longBreakDuration = await _storage.loadLongBreakDuration(uid ?? '');
    final pomodorosBefore = await _storage.loadPomodorosBeforeLongBreak(uid ?? '');
    if (mounted) {
      setState(() {
        _presets = presets;
        _breakMinutes = breakDuration;
        _longBreakMinutes = longBreakDuration;
        _pomodorosBeforeLongBreak = pomodorosBefore;
      });
    }
    _syncFromCloud();
  }

  Future<void> _syncFromCloud() async {
    try {
      final repo = context.read<SessionRepository>();
      final prefs = await repo.fetchPreferences();
      if (prefs != null && mounted) {
        final cloudPresets = (prefs['presets'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList();
        final cloudBreak = prefs['break_duration'] as int?;
        final cloudLongBreak = prefs['long_break_duration'] as int?;
        final cloudPomodorosBefore =
            prefs['pomodoros_before_long_break'] as int?;
        setState(() {
          if (cloudPresets != null && cloudPresets.isNotEmpty) {
            _presets = cloudPresets;
          }
          if (cloudBreak != null) _breakMinutes = cloudBreak;
          if (cloudLongBreak != null) _longBreakMinutes = cloudLongBreak;
          if (cloudPomodorosBefore != null) {
            _pomodorosBeforeLongBreak = cloudPomodorosBefore;
          }
        });
      }
    } catch (_) {}
  }

  void _saveAll() {
    final uid = _userId ?? '';
    _storage.savePresets(uid, _presets);
    _storage.saveBreakDuration(uid, _breakMinutes);
    _storage.saveLongBreakDuration(uid, _longBreakMinutes);
    _storage.savePomodorosBeforeLongBreak(uid, _pomodorosBeforeLongBreak);
    try {
      context.read<SessionRepository>().savePreferences(
        _presets,
        _breakMinutes,
        longBreakDuration: _longBreakMinutes,
        pomodorosBeforeLongBreak: _pomodorosBeforeLongBreak,
      );
    } catch (_) {}
  }

  void _addPreset() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom duration'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Minutes',
            suffixText: 'min',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1 && val <= 480) {
                setState(() {
                  _presets.add(val);
                  _presets.sort();
                });
                _saveAll();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removePreset(int minutes) {
    if (_presets.length <= 1) return;
    setState(() {
      _presets.remove(minutes);
    });
    _saveAll();
  }

  void _showAdjustDialog(String title, int current, int min, int max,
      ValueChanged<int> onChanged) {
    int temp = current;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: temp > min
                    ? () => setDialogState(() => temp--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '$temp min',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: temp < max
                    ? () => setDialogState(() => temp++)
                    : null,
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
                onChanged(temp);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildSectionHeader('Timer Presets'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _presets)
              Chip(
                label: Text('${m}m'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removePreset(m),
                backgroundColor: const Color(0xFFF4EFE6),
                side: const BorderSide(color: Color(0xFFDDD2C2)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: _addPreset,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFDDD2C2)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Short Break'),
        const SizedBox(height: 4),
        _buildSettingTile(
          label: 'Duration',
          value: '$_breakMinutes min',
          onTap: () {
            _showAdjustDialog('Short break duration', _breakMinutes, 1, 30,
                (m) {
              setState(() => _breakMinutes = m);
              _saveAll();
            });
          },
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Long Break'),
        const SizedBox(height: 4),
        _buildSettingTile(
          label: 'Duration',
          value: '$_longBreakMinutes min',
          onTap: () {
            _showAdjustDialog('Long break duration', _longBreakMinutes, 1, 60,
                (m) {
              setState(() => _longBreakMinutes = m);
              _saveAll();
            });
          },
        ),
        _buildSettingTile(
          label: 'Pomodoros before long break',
          value: '$_pomodorosBeforeLongBreak',
          onTap: () {
            _showAdjustDialog(
                'Pomodoros before long break', _pomodorosBeforeLongBreak, 2, 10,
                (n) {
              setState(() => _pomodorosBeforeLongBreak = n);
              _saveAll();
            });
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'After $_pomodorosBeforeLongBreak pomodoros, you\'ll get a ${_longBreakMinutes}-minute long break instead of ${_breakMinutes} minutes.',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF3A2E27).withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3A2E27),
      ),
    );
  }

  Widget _buildSettingTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDD2C2)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF3A2E27),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3A2E27).withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: const Color(0xFF3A2E27).withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}
