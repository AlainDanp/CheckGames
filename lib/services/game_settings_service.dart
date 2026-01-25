import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';

/// Service pour gérer les paramètres du jeu
class GameSettingsService {
  static final GameSettingsService _instance = GameSettingsService._internal();
  factory GameSettingsService() => _instance;
  GameSettingsService._internal();

  static GameSettingsService get instance => _instance;

  SharedPreferences? _prefs;

  // Clés de stockage
  static const String _keyBotCount = 'bot_count';
  static const String _keyDifficulty = 'difficulty';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyMusicEnabled = 'music_enabled';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyGameSpeed = 'game_speed';
  static const String _keySelectedMusic = 'selected_music';

  // Valeurs par défaut
  static const int defaultBotCount = 2;
  static const BotDifficulty defaultDifficulty = BotDifficulty.normal;
  static const bool defaultSoundEnabled = true;
  static const bool defaultMusicEnabled = true;
  static const bool defaultVibrationEnabled = true;
  static const GameSpeed defaultGameSpeed = GameSpeed.normal;
  static const GameMusic defaultSelectedMusic = GameMusic.arcticMonkeys;

  /// Initialiser le service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============================================================================
  // NOMBRE DE BOTS
  // ============================================================================

  /// Obtenir le nombre de bots (1-3)
  int get botCount => _prefs?.getInt(_keyBotCount) ?? defaultBotCount;

  /// Définir le nombre de bots
  Future<void> setBotCount(int count) async {
    await _prefs?.setInt(_keyBotCount, count.clamp(1, 3));
  }

  // ============================================================================
  // DIFFICULTÉ
  // ============================================================================

  /// Obtenir la difficulté des bots
  BotDifficulty get difficulty {
    final index = _prefs?.getInt(_keyDifficulty) ?? defaultDifficulty.index;
    return BotDifficulty.values[index.clamp(0, BotDifficulty.values.length - 1)];
  }

  /// Définir la difficulté des bots
  Future<void> setDifficulty(BotDifficulty difficulty) async {
    await _prefs?.setInt(_keyDifficulty, difficulty.index);
  }

  // ============================================================================
  // SON
  // ============================================================================

  /// Vérifier si le son est activé
  bool get soundEnabled => _prefs?.getBool(_keySoundEnabled) ?? defaultSoundEnabled;

  /// Activer/désactiver le son
  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs?.setBool(_keySoundEnabled, enabled);
  }

  // ============================================================================
  // MUSIQUE
  // ============================================================================

  /// Vérifier si la musique est activée
  bool get musicEnabled => _prefs?.getBool(_keyMusicEnabled) ?? defaultMusicEnabled;

  /// Activer/désactiver la musique
  Future<void> setMusicEnabled(bool enabled) async {
    await _prefs?.setBool(_keyMusicEnabled, enabled);
  }

  /// Obtenir la musique sélectionnée
  GameMusic get selectedMusic {
    final index = _prefs?.getInt(_keySelectedMusic) ?? defaultSelectedMusic.index;
    return GameMusic.values[index.clamp(0, GameMusic.values.length - 1)];
  }

  /// Définir la musique sélectionnée
  Future<void> setSelectedMusic(GameMusic music) async {
    await _prefs?.setInt(_keySelectedMusic, music.index);
  }

  // ============================================================================
  // VIBRATIONS
  // ============================================================================

  /// Vérifier si les vibrations sont activées
  bool get vibrationEnabled => _prefs?.getBool(_keyVibrationEnabled) ?? defaultVibrationEnabled;

  /// Activer/désactiver les vibrations
  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs?.setBool(_keyVibrationEnabled, enabled);
  }

  // ============================================================================
  // VITESSE DU JEU
  // ============================================================================

  /// Obtenir la vitesse du jeu
  GameSpeed get gameSpeed {
    final index = _prefs?.getInt(_keyGameSpeed) ?? defaultGameSpeed.index;
    return GameSpeed.values[index.clamp(0, GameSpeed.values.length - 1)];
  }

  /// Définir la vitesse du jeu
  Future<void> setGameSpeed(GameSpeed speed) async {
    await _prefs?.setInt(_keyGameSpeed, speed.index);
  }

  /// Obtenir le délai en millisecondes selon la vitesse
  int get botDelayMs {
    switch (gameSpeed) {
      case GameSpeed.slow:
        return 2000;
      case GameSpeed.normal:
        return 1000;
      case GameSpeed.fast:
        return 500;
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Générer la liste des noms de joueurs selon les paramètres
  List<String> generatePlayerNames() {
    final names = ['Vous'];
    for (int i = 1; i <= botCount; i++) {
      names.add('Bot $i');
    }
    return names;
  }

  /// Réinitialiser tous les paramètres
  Future<void> resetToDefaults() async {
    await setBotCount(defaultBotCount);
    await setDifficulty(defaultDifficulty);
    await setSoundEnabled(defaultSoundEnabled);
    await setMusicEnabled(defaultMusicEnabled);
    await setSelectedMusic(defaultSelectedMusic);
    await setVibrationEnabled(defaultVibrationEnabled);
    await setGameSpeed(defaultGameSpeed);
  }
}

/// Niveaux de difficulté des bots
enum BotDifficulty {
  easy,
  normal,
  hard;

  String get displayName {
    switch (this) {
      case BotDifficulty.easy:
        return 'Facile';
      case BotDifficulty.normal:
        return 'Normal';
      case BotDifficulty.hard:
        return 'Difficile';
    }
  }

  String get description {
    switch (this) {
      case BotDifficulty.easy:
        return 'Les bots jouent de manière aléatoire';
      case BotDifficulty.normal:
        return 'Les bots jouent de manière équilibrée';
      case BotDifficulty.hard:
        return 'Les bots jouent de manière optimale';
    }
  }
}

/// Vitesse du jeu
enum GameSpeed {
  slow,
  normal,
  fast;

  String get displayName {
    switch (this) {
      case GameSpeed.slow:
        return 'Lente';
      case GameSpeed.normal:
        return 'Normale';
      case GameSpeed.fast:
        return 'Rapide';
    }
  }

  String get description {
    switch (this) {
      case GameSpeed.slow:
        return 'Plus de temps pour réfléchir';
      case GameSpeed.normal:
        return 'Vitesse standard';
      case GameSpeed.fast:
        return 'Pour les joueurs expérimentés';
    }
  }
}
