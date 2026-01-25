import 'package:audioplayers/audioplayers.dart';
import 'game_settings_service.dart';

/// Liste des musiques disponibles dans le jeu
enum GameMusic {
  arcticMonkeys,
  billWithers,
  lesJongleurs,
  lou,
  werenoi;

  /// Nom d'affichage de la musique
  String get displayName {
    switch (this) {
      case GameMusic.arcticMonkeys:
        return 'I Wanna Be Yours';
      case GameMusic.billWithers:
        return "Ain't No Sunshine";
      case GameMusic.lesJongleurs:
        return 'Les Jongleurs';
      case GameMusic.lou:
        return 'Le Paradis Sur Terre';
      case GameMusic.werenoi:
        return '3 Singes';
    }
  }

  /// Artiste de la musique
  String get artist {
    switch (this) {
      case GameMusic.arcticMonkeys:
        return 'Arctic Monkeys';
      case GameMusic.billWithers:
        return 'Bill Withers';
      case GameMusic.lesJongleurs:
        return 'Les Jongleurs';
      case GameMusic.lou:
        return 'LOU!';
      case GameMusic.werenoi:
        return 'Werenoi ft. Ninho';
    }
  }

  /// Description complète (artiste - titre)
  String get description => artist;

  /// Nom du fichier audio
  String get fileName {
    switch (this) {
      case GameMusic.arcticMonkeys:
        return 'Arctic Monkeys - I Wanna Be Yours';
      case GameMusic.billWithers:
        return 'Bill Withers - Aint No Sunshine';
      case GameMusic.lesJongleurs:
        return 'LES JONGLEURS';
      case GameMusic.lou:
        return 'LOU! - Le Paradis Sur Terre';
      case GameMusic.werenoi:
        return 'Werenoi - 3 Singes (Feat. Ninho)';
    }
  }

  /// Chemin complet du fichier
  String get assetPath => 'sounds/music/$fileName.mp3';
}

class AudioService {
  static final AudioService instance = AudioService._internal();
  factory AudioService() => instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer(); // Pour les effets sonores
  final AudioPlayer _musicPlayer = AudioPlayer(); // Pour la musique de fond

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _isMusicPlaying = false;
  GameMusic _currentMusic = GameMusic.arcticMonkeys;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get isMusicPlaying => _isMusicPlaying;
  GameMusic get currentMusic => _currentMusic;

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (_musicEnabled && !_isMusicPlaying) {
      startBackgroundMusic();
    } else if (!_musicEnabled && _isMusicPlaying) {
      stopBackgroundMusic();
    }
  }

  void setMusicEnabled(bool enabled, {bool autoStart = false}) {
    _musicEnabled = enabled;
    if (_musicEnabled && !_isMusicPlaying && autoStart) {
      startBackgroundMusic();
    } else if (!_musicEnabled && _isMusicPlaying) {
      stopBackgroundMusic();
    }
  }

  /// Change la musique de fond
  Future<void> setMusic(GameMusic music) async {
    _currentMusic = music;
    // Sauvegarder dans les paramètres
    await GameSettingsService.instance.setSelectedMusic(music);

    // Si la musique joue, changer de piste
    if (_isMusicPlaying) {
      await stopBackgroundMusic();
      await startBackgroundMusic();
    }
  }

  /// Charge la musique depuis les paramètres
  void loadMusicFromSettings() {
    _currentMusic = GameSettingsService.instance.selectedMusic;
  }

  Future<void> startBackgroundMusic() async {
    if (!_musicEnabled || _isMusicPlaying) return;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop); // Jouer en boucle
      await _musicPlayer.setVolume(0.3); // Volume à 30%
      await _musicPlayer.play(AssetSource(_currentMusic.assetPath));
      _isMusicPlaying = true;
    } catch (e) {
      // Musique non trouvée, essayer le fallback
      try {
        await _musicPlayer.play(AssetSource('sounds/background_music.mp3'));
        _isMusicPlaying = true;
      } catch (e2) {
        // Aucune musique trouvée
      }
    }
  }

  Future<void> stopBackgroundMusic() async {
    await _musicPlayer.stop();
    _isMusicPlaying = false;
  }

  Future<void> pauseBackgroundMusic() async {
    await _musicPlayer.pause();
  }

  Future<void> resumeBackgroundMusic() async {
    if (_musicEnabled) {
      await _musicPlayer.resume();
    }
  }

  /// Prévisualise une musique sans la définir comme musique actuelle
  Future<void> previewMusic(GameMusic music) async {
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.3);
      await _musicPlayer.play(AssetSource(music.assetPath));
      _isMusicPlaying = true;
    } catch (e) {
      // Musique non trouvée
    }
  }

  Future<void> playCardMove() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('sounds/card_move.mp3'));
    } catch (e) {
      // Son non trouvé, on ignore l'erreur
    }
  }

  Future<void> playChecks() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('sounds/checks.mp3'));
    } catch (e) {
      // Son non trouvé, on ignore l'erreur
    }
  }

  Future<void> playButtonClick() async {
    if (!_soundEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('sounds/button_click.mp3'));
    } catch (e) {
      // Son non trouvé, on ignore l'erreur
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
  }
}
