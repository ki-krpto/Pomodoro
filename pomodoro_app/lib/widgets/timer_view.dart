import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../repositories/session_repository.dart';
import '../services/auth_service.dart';
import '../services/local_storage.dart';
import '../services/session_manager.dart';
import '../services/subject_manager.dart';
import '../services/audio_service.dart';
import '../services/spotify_service.dart';
import 'cork_board.dart';
import 'spotify_player.dart';

class TimerView extends StatefulWidget {
  final ValueChanged<bool>? onFocusModeChanged;

  const TimerView({super.key, this.onFocusModeChanged});

  @override
  State<TimerView> createState() => _TimerViewState();
}

class _TimerViewState extends State<TimerView> {
  List<int> _presets = LocalStorage.defaultPresets;
  int _breakMinutes = LocalStorage.defaultBreakDuration;
  int _longBreakMinutes = LocalStorage.defaultLongBreakDuration;
  int _pomodorosBeforeLongBreak = LocalStorage.defaultPomodorosBeforeLongBreak;
  int _pomodorosCompletedInCycle = 0;
  final LocalStorage _storage = LocalStorage();

  int _selectedMinutes = 25;
  _TimerState _state = _TimerState.idle;
  Duration _remaining = const Duration(minutes: 25);
  Timer? _ticker;
  int _newestIndex = -1;
  String? _selectedSubjectId;

  bool _isBreak = false;
  bool _workComplete = false;
  final AudioPlayer _notificationPlayer = AudioPlayer();

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
        if (!_presets.contains(_selectedMinutes)) {
          _selectedMinutes = _presets.first;
        }
        _remaining = Duration(minutes: _selectedMinutes);
      });
    }
    _syncPreferencesFromCloud();
  }

  Future<void> _syncPreferencesFromCloud() async {
    try {
      final repo = context.read<SessionRepository>();
      final prefs = await repo.fetchPreferences();
      if (prefs != null && mounted) {
        final cloudPresets = (prefs['presets'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList();
        final cloudBreak = prefs['break_duration'] as int?;
        final cloudLongBreak = prefs['long_break_duration'] as int?;
        final cloudPomodorosBefore = prefs['pomodoros_before_long_break'] as int?;
        setState(() {
          if (cloudPresets != null && cloudPresets.isNotEmpty) {
            _presets = cloudPresets;
          }
          if (cloudBreak != null) {
            _breakMinutes = cloudBreak;
          }
          if (cloudLongBreak != null) {
            _longBreakMinutes = cloudLongBreak;
          }
          if (cloudPomodorosBefore != null) {
            _pomodorosBeforeLongBreak = cloudPomodorosBefore;
          }
          if (!_presets.contains(_selectedMinutes)) {
            _selectedMinutes = _presets.first;
          }
          _remaining = Duration(minutes: _selectedMinutes);
        });
      }
    } catch (_) {}
  }

  void _savePreferences() {
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

  @override
  void dispose() {
    _ticker?.cancel();
    _notificationPlayer.dispose();
    super.dispose();
  }

  void _selectDuration(int minutes) {
    if (_state != _TimerState.idle) return;
    setState(() {
      _selectedMinutes = minutes;
      _remaining = Duration(minutes: minutes);
    });
  }

  void _addCustomPreset() {
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
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 1 || value > 480) return;
              if (_presets.contains(value)) return Navigator.pop(ctx);
              setState(() => _presets = [..._presets, value]..sort());
              _savePreferences();
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
      _presets = _presets.where((m) => m != minutes).toList();
      if (_selectedMinutes == minutes && _presets.isNotEmpty) {
        _selectedMinutes = _presets.first;
        _remaining = Duration(minutes: _selectedMinutes);
      }
    });
    _savePreferences();
  }

  void _startTicking() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 1) {
        _onTickComplete();
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _isBreak = false;
      _state = _TimerState.running;
      _remaining = Duration(minutes: _selectedMinutes);
      _newestIndex = -1;
    });
    widget.onFocusModeChanged?.call(true);
    _startTicking();
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _state = _TimerState.paused);
  }

  void _resume() {
    setState(() => _state = _TimerState.running);
    _startTicking();
  }

  void _cancel() {
    _ticker?.cancel();
    setState(() {
      _isBreak = false;
      _state = _TimerState.idle;
      _remaining = Duration(minutes: _selectedMinutes);
      _workComplete = false;
    });
    widget.onFocusModeChanged?.call(false);
  }

  Future<void> _onTickComplete() async {
    _ticker?.cancel();
    _playNotificationSound();

    if (!_isBreak) {
      await context
          .read<SessionManager>()
          .completeSession(_selectedMinutes, subjectId: _selectedSubjectId);
      _pomodorosCompletedInCycle++;
      final useLongBreak =
          _pomodorosCompletedInCycle >= _pomodorosBeforeLongBreak;
      final breakDuration = useLongBreak ? _longBreakMinutes : _breakMinutes;
      setState(() {
        _newestIndex = context.read<SessionManager>().sessions.length - 1;
        _isBreak = true;
        _state = _TimerState.paused;
        _remaining = Duration(minutes: breakDuration);
        _workComplete = true;
      });
    } else {
      final wasLongBreak =
          _pomodorosCompletedInCycle >= _pomodorosBeforeLongBreak;
      if (wasLongBreak) {
        _pomodorosCompletedInCycle = 0;
      }
      setState(() {
        _isBreak = false;
        _state = _TimerState.paused;
        _remaining = Duration(minutes: _selectedMinutes);
        _workComplete = false;
      });
    }
  }

  void _playNotificationSound() {
    try {
      _notificationPlayer.stop();
      _notificationPlayer.play(AssetSource('audio/timer_complete.wav'));
    } catch (e) {
      debugPrint('Notification sound error: $e');
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _startBreakFromPaused() {
    setState(() {
      _state = _TimerState.running;
    });
    _startTicking();
  }

  Future<void> _requestExit() async {
    if (_state == _TimerState.idle) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isBreak ? 'Skip break?' : 'End session?'),
        content: Text(_isBreak
            ? 'Skip the remaining break?'
            : 'End this focus session early? The session won\'t be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isBreak ? 'Skip break' : 'End session'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _cancel();
    }
  }

  String get _clock {
    final m = _remaining.inMinutes.toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _phaseLabel {
    if (_workComplete && _isBreak) {
      final isLongBreak =
          _pomodorosCompletedInCycle >= _pomodorosBeforeLongBreak;
      return isLongBreak ? 'Long Break' : 'Break time';
    }
    return _isBreak ? 'Take a break' : 'Stay focused';
  }

  Future<void> _debugAddSessions() async {
    const count = 5;
    await context.read<SessionManager>().debugBatchSessions(count,
        subjectId: _selectedSubjectId);
    setState(() {
      _newestIndex = context.read<SessionManager>().sessions.length - 1;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $count test sessions'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _debugClearSessions() async {
    await context.read<SessionManager>().clearAllSessions();
    setState(() => _newestIndex = -1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Board cleared'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _state == _TimerState.idle
          ? _buildHomeLayout()
          : _buildFocusLayout(),
    );
  }

  Widget _buildHomeLayout() {
    return Column(
      key: const ValueKey('home'),
      children: [
        _TopBar(
          onTitleLongPress: _debugAddSessions,
          onSubtitleLongPress: _debugClearSessions,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Consumer<SessionManager>(
              builder: (ctx, manager, _) => CorkBoard(
                sessions: manager.sessions,
                newestAnimatedIndex: _newestIndex,
              ),
            ),
          ),
        ),
        _BottomControls(
          presets: _presets,
          selectedMinutes: _selectedMinutes,
          onSelectDuration: _selectDuration,
          onAddPreset: _addCustomPreset,
          onRemovePreset: _removePreset,
          onStart: _start,
          selectedSubjectId: _selectedSubjectId,
          onSubjectChanged: (id) => setState(() => _selectedSubjectId = id),
        ),
      ],
    );
  }

  Widget _buildFocusLayout() {
    final bgColor = _isBreak
        ? const Color(0xFFE8F5E9).withOpacity(0.3)
        : const Color(0xFFF4EFE6);

    return Container(
      key: const ValueKey('focus'),
      color: bgColor,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _requestExit,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: const Color(0xFF3A2E27).withOpacity(0.6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_isBreak
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF8B5A2B))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isBreak ? 'Break' : 'Focus Session',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isBreak
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF8B5A2B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _clock,
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w200,
                      color: Color(0xFF3A2E27),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _phaseLabel,
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF3A2E27).withOpacity(0.5),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom area: music + controls
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              children: [
                if (!_isBreak) ...[
                  const _MusicIndicator(),
                  const SizedBox(height: 12),
                  const _MusicButton(),
                  const SizedBox(height: 20),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_workComplete && _isBreak) ...[
                      _ActionButton(
                        label: 'Start Break',
                        onTap: _startBreakFromPaused,
                        filled: true,
                      ),
                      const SizedBox(width: 16),
                      _ActionButton(
                        label: 'End',
                        onTap: _requestExit,
                        filled: false,
                      ),
                    ] else ...[
                      _ActionButton(
                        label:
                            _state == _TimerState.running ? 'Pause' : 'Resume',
                        onTap:
                            _state == _TimerState.running ? _pause : _resume,
                        filled: false,
                      ),
                      const SizedBox(width: 16),
                      _ActionButton(
                        label: 'End',
                        onTap: _requestExit,
                        filled: true,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TimerState { idle, running, paused }

class _TopBar extends StatelessWidget {
  final VoidCallback? onTitleLongPress;
  final VoidCallback? onSubtitleLongPress;

  const _TopBar({
    this.onTitleLongPress,
    this.onSubtitleLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: onTitleLongPress,
            child: const Text(
              'Focus Board',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A2E27),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onLongPress: onSubtitleLongPress,
            child: Text(
              'Long press to debug',
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF3A2E27).withOpacity(0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final List<int> presets;
  final int selectedMinutes;
  final ValueChanged<int> onSelectDuration;
  final VoidCallback onAddPreset;
  final ValueChanged<int> onRemovePreset;
  final VoidCallback onStart;
  final String? selectedSubjectId;
  final ValueChanged<String?> onSubjectChanged;

  const _BottomControls({
    required this.presets,
    required this.selectedMinutes,
    required this.onSelectDuration,
    required this.onAddPreset,
    required this.onRemovePreset,
    required this.onStart,
    this.selectedSubjectId,
    required this.onSubjectChanged,
  });

  void _showSubjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<SubjectManager>(
          builder: (ctx, sm, _) {
            final subjects = sm.subjects;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Select Subject',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3A2E27),
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        Icons.check,
                        color: selectedSubjectId == null
                            ? const Color(0xFF8B5A2B)
                            : Colors.transparent,
                      ),
                      title: const Text('None'),
                      onTap: () {
                        onSubjectChanged(null);
                        Navigator.pop(ctx);
                      },
                    ),
                    if (subjects.isNotEmpty) ...[
                      const Divider(height: 1),
                      for (final s in subjects)
                        ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check,
                                color: selectedSubjectId == s.id
                                    ? const Color(0xFF8B5A2B)
                                    : Colors.transparent,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          title: Text(s.name),
                          onTap: () {
                            onSubjectChanged(s.id);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add, size: 20),
                      title: const Text('Create new subject'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreateSubjectDialog(context);
                      },
                    ),
                    if (subjects.isNotEmpty)
                      ListTile(
                        leading:
                            const Icon(Icons.settings_outlined, size: 20),
                        title: const Text('Manage subjects'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showManageSubjectsDialog(context);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateSubjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color? pickedColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Subject name',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _subjectPresetColors)
                    GestureDetector(
                      onTap: () =>
                          setDialogState(() => pickedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: pickedColor == c
                              ? Border.all(
                                  color: const Color(0xFF3A2E27),
                                  width: 2.5)
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
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final sm = context.read<SubjectManager>();
                sm.createSubject(name, color: pickedColor).then((s) {
                  onSubjectChanged(s.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                });
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageSubjectsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<SubjectManager>(
        builder: (ctx, sm, _) {
          final subjects = sm.subjects;
          return AlertDialog(
            title: const Text('Manage subjects'),
            content: SizedBox(
              width: double.maxFinite,
              child: subjects.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No subjects yet.',
                          textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: subjects.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final s = subjects[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(s.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showRenameSubjectDialog(
                                      context, s.id, s.name);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: Colors.redAccent),
                                onPressed: () {
                                  sm.deleteSubject(s.id);
                                  if (selectedSubjectId == s.id) {
                                    onSubjectChanged(null);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenameSubjectDialog(
      BuildContext context, String id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename subject'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
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
              context.read<SubjectManager>().renameSubject(id, name);
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjectManager = context.watch<SubjectManager>();
    final selectedSubject = selectedSubjectId != null
        ? subjectManager.getSubject(selectedSubjectId)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final minutes in presets)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onLongPress: () => onRemovePreset(minutes),
                    child: _DurationChip(
                      minutes: minutes,
                      selected: selectedMinutes == minutes,
                      onTap: () => onSelectDuration(minutes),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onAddPreset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDD2C2)),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: const Color(0xFF3A2E27).withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              const _MusicButton(),
              const Spacer(),
              GestureDetector(
                onTap: () => _showSubjectSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDD2C2)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selectedSubject?.color ??
                              const Color(0xFFBBB5AB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedSubject?.name ?? 'None',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down,
                          size: 16,
                          color: const Color(0xFF3A2E27).withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ActionButton(label: 'START', onTap: onStart, filled: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _MusicButton extends StatelessWidget {
  const _MusicButton();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioService>();
    return GestureDetector(
      onTap: () => _showSoundSheet(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: audio.isPlaying
              ? const Color(0xFF8B5A2B).withOpacity(0.15)
              : Colors.white.withOpacity(0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          audio.isPlaying ? Icons.music_note : Icons.music_note_outlined,
          size: 22,
          color: audio.isPlaying
              ? const Color(0xFF8B5A2B)
              : const Color(0xFF3A2E27).withOpacity(0.5),
        ),
      ),
    );
  }

  void _showSoundSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Music',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3A2E27),
                      ),
                    ),
                  ),
                  const Divider(),
                  // Spotify section
                  const SpotifySection(),
                  const Divider(height: 24),
                  // Ambient sounds section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Ambient Sounds',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3A2E27).withOpacity(0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer<AudioService>(
                    builder: (ctx, audio, _) {
                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.check,
                              size: 18,
                              color: !audio.isPlaying
                                  ? const Color(0xFF8B5A2B)
                                  : Colors.transparent,
                            ),
                            title: const Text('None', style: TextStyle(fontSize: 14)),
                            onTap: () {
                              audio.stop();
                              Navigator.pop(ctx);
                            },
                          ),
                          for (final sound in AudioService.availableSounds)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.check,
                                size: 18,
                                color: audio.currentSound == sound.id
                                    ? const Color(0xFF8B5A2B)
                                    : Colors.transparent,
                              ),
                              title: Row(
                                children: [
                                  Icon(sound.icon,
                                      size: 16,
                                      color: const Color(0xFF3A2E27)
                                          .withOpacity(0.6)),
                                  const SizedBox(width: 8),
                                  Text(sound.label,
                                      style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                              onTap: () {
                                audio.play(sound.id);
                                Navigator.pop(ctx);
                              },
                            ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.volume_down,
                                    size: 16,
                                    color: const Color(0xFF3A2E27)
                                        .withOpacity(0.5)),
                                Expanded(
                                  child: Slider(
                                    value: audio.volume,
                                    min: 0.1,
                                    max: 2.0,
                                    divisions: 19,
                                    activeColor: const Color(0xFF8B5A2B),
                                    inactiveColor: const Color(0xFFDDD2C2),
                                    onChanged: (v) => audio.setVolume(v),
                                  ),
                                ),
                                Icon(Icons.volume_up,
                                    size: 16,
                                    color: const Color(0xFF3A2E27)
                                        .withOpacity(0.5)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MusicIndicator extends StatelessWidget {
  const _MusicIndicator();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioService>();
    final spotify = context.watch<SpotifyService>();

    // Spotify is playing
    if (spotify.isPlaying && spotify.currentTrack != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF1DB954)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${spotify.currentTrack!.name} - ${spotify.currentTrack!.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF3A2E27).withOpacity(0.4)),
            ),
          ),
        ],
      );
    }

    // Ambient sound is playing
    if (!audio.isPlaying) return const SizedBox.shrink();
    final sound = AudioService.availableSounds
        .where((s) => s.id == audio.currentSound)
        .firstOrNull;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.music_note,
            size: 14,
            color: const Color(0xFF3A2E27).withOpacity(0.4)),
        const SizedBox(width: 4),
        Text(
          sound?.label ?? '',
          style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF3A2E27).withOpacity(0.4)),
        ),
      ],
    );
  }
}

const List<Color> _subjectPresetColors = [
  Color(0xFFF4D35E),
  Color(0xFFA8C69F),
  Color(0xFF8FAFC4),
  Color(0xFFD9A5A0),
  Color(0xFFB79FC4),
  Color(0xFFF4A261),
  Color(0xFF7EC8E3),
  Color(0xFFE8A0BF),
];

class _DurationChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8B5A2B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5A2B)
                : const Color(0xFFDDD2C2),
          ),
        ),
        child: Text(
          '${minutes}m',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF3A2E27),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: filled ? const Color(0xFF8B5A2B) : Colors.white,
        foregroundColor: filled ? Colors.white : const Color(0xFF3A2E27),
        elevation: 0,
        side: filled
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFDDD2C2)),
        padding: EdgeInsets.symmetric(
          horizontal: filled ? 24 : 18,
          vertical: filled ? 14 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}
