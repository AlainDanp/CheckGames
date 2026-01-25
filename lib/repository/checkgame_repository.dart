import 'package:hive_flutter/hive_flutter.dart';
import '../models/player_stats.dart';
import '../models/game_history.dart';

class CheckgameRepository {
  static const String _statsBoxName = 'player_stats';
  static const String _historyBoxName = 'game_history';

  Box<PlayerStats>? _statsBox;
  Box<GameHistory>? _historyBox;

  /// Initialiser Hive (à appeler dans main.dart)
  Future<void> init() async {
    await Hive.initFlutter();

    // Enregistrer les adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PlayerStatsAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(GameHistoryAdapter());
    }

    // Ouvrir les boxes
    _statsBox = await Hive.openBox<PlayerStats>(_statsBoxName);
    _historyBox = await Hive.openBox<GameHistory>(_historyBoxName);
  }

  /// Récupérer les stats d'un joueur
  PlayerStats getPlayerStats(String playerName) {
    if (_statsBox == null) {
      // Box non initialisée, retourner stats par défaut sans erreur
      return PlayerStats(playerName: playerName);
    }
    final stats = _statsBox!.get(playerName);
    return stats ?? PlayerStats(playerName: playerName);
  }

  /// Sauvegarder les stats d'un joueur
  Future<void> savePlayerStats(PlayerStats stats) async {
    if (_statsBox == null) {
      // Impossible de sauvegarder si box non initialisée
      return;
    }
    try {
      await _statsBox!.put(stats.playerName, stats);
    } catch (e) {
      // Ignorer les erreurs silencieusement (on pourrait logger ici)
      return;
    }
  }

  /// Enregistrer le résultat d'une partie
  Future<void> recordGameResult({
    required String playerName,
    required int position,
  }) async {
    final currentStats = getPlayerStats(playerName);
    final updatedStats = currentStats.recordGame(position);
    await savePlayerStats(updatedStats);
  }

  /// Sauvegarder une partie dans l'historique
  Future<void> saveGameHistory(GameHistory history) async {
    if (_historyBox == null) {
      // Impossible de sauvegarder si box non initialisée
      return;
    }
    try {
      await _historyBox!.add(history);

      // Limiter à 50 parties max
      if (_historyBox!.length > 50) {
        await _historyBox!.deleteAt(0);
      }
    } catch (e) {
      // Ignorer les erreurs silencieusement (on pourrait logger ici)
      return;
    }
  }

  /// Récupérer l'historique des parties
  List<GameHistory> getGameHistory({int limit = 20}) {
    if (_historyBox == null) {
      // Box non initialisée, retourner liste vide
      return [];
    }
    try {
      final all = _historyBox!.values.toList();
      return all.reversed.take(limit).toList();
    } catch (e) {
      // En cas d'erreur, retourner liste vide
      return [];
    }
  }

  /// Effacer toutes les données
  Future<void> clearAll() async {
    try {
      if (_statsBox != null) await _statsBox!.clear();
      if (_historyBox != null) await _historyBox!.clear();
    } catch (e) {
      // Ignorer les erreurs silencieusement
      return;
    }
  }
}
