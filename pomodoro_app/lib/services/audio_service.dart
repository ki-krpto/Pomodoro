import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SoundOption {
  final String id;
  final String label;
  final IconData icon;

  const SoundOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  String? _currentSound;
  bool _isPlaying = false;
  double _volume = 1.0;

  static const List<SoundOption> availableSounds = [
    SoundOption(id: 'rain', label: 'Rain', icon: Icons.water_drop),
    SoundOption(id: 'ocean', label: 'Ocean', icon: Icons.waves),
    SoundOption(id: 'forest', label: 'Forest', icon: Icons.nature),
    SoundOption(id: 'white_noise', label: 'White Noise', icon: Icons.tune),
  ];

  String? get currentSound => _currentSound;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  Future<void> play(String id) async {
    if (id == _currentSound && _isPlaying) {
      await stop();
      return;
    }
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/$id.mp3'));
      _currentSound = id;
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioService: $e');
      _currentSound = null;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.1, 2.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSound = null;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
