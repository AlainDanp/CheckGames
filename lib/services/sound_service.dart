import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Getters
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  // Setters
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  // Sons multiplayer
  Future<void> playJoinSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/join.mp3'));
      _vibrate(duration: 50);
    } catch (e) {
      // Ignorer les erreurs de son manquant
    }
  }

  Future<void> playReadySound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/ready.mp3'));
      _vibrate(duration: 30);
    } catch (e) {
      // Ignorer les erreurs de son manquant
    }
  }

  Future<void> playStartSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/start.mp3'));
      _vibrate(pattern: [0, 50, 100, 50]);
    } catch (e) {
      // Ignorer les erreurs de son manquant
    }
  }

  Future<void> playMessageSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/message.mp3'));
      _vibrate(duration: 20);
    } catch (e) {
      // Ignorer les erreurs de son manquant
    }
  }

  Future<void> playLeaveSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/leave.mp3'));
    } catch (e) {
      // Ignorer les erreurs de son manquant
    }
  }

  Future<void> playButtonClick() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/click.mp3'));
      _vibrate(duration: 10);
    } catch (e) {
      // Ignorer les erreurs de son manquant
    }
  }

  Future<void> playCopySound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/copy.mp3'));
      _vibrate(duration: 30);
    } catch (e) {
      // Ignorer les erreurs de son manquant
    }
  }

  // Vibrations
  Future<void> _vibrate({int? duration, List<int>? pattern}) async {
    if (!_vibrationEnabled) return;
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        if (pattern != null) {
          await Vibration.vibrate(pattern: pattern);
        } else if (duration != null) {
          await Vibration.vibrate(duration: duration);
        } else {
          await Vibration.vibrate();
        }
      }
    } catch (e) {
      // Vibration non supportee
    }
  }

  // Vibrations publiques
  Future<void> vibrateLight() async {
    _vibrate(duration: 20);
  }

  Future<void> vibrateMedium() async {
    _vibrate(duration: 50);
  }

  Future<void> vibrateHeavy() async {
    _vibrate(duration: 100);
  }

  Future<void> vibrateSuccess() async {
    _vibrate(pattern: [0, 30, 100, 30]);
  }

  Future<void> vibrateError() async {
    _vibrate(pattern: [0, 50, 100, 50, 100, 50]);
  }

  // Cleanup
  void dispose() {
    _audioPlayer.dispose();
  }
}
