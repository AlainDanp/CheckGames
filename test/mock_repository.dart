import 'package:checkgame/repository/checkgame_repository.dart';
import 'package:checkgame/models/player_stats.dart';
import 'package:checkgame/models/game_history.dart';

class MockRepository extends CheckgameRepository {
  final List<GameHistory> _history = [];
  final Map<String, PlayerStats> _stats = {};

  @override
  Future<void> init() async {
    // Mock: rien à initialiser
  }

  @override
  PlayerStats getPlayerStats(String playerName) {
    return _stats[playerName] ?? PlayerStats(playerName: playerName);
  }

  @override
  Future<void> savePlayerStats(PlayerStats stats) async {
    _stats[stats.playerName] = stats;
  }

  @override
  Future<void> recordGameResult({
    required String playerName,
    required int position,
  }) async {
    final currentStats = getPlayerStats(playerName);
    final updatedStats = currentStats.recordGame(position);
    await savePlayerStats(updatedStats);
  }

  @override
  Future<void> saveGameHistory(GameHistory history) async {
    _history.add(history);
  }

  @override
  List<GameHistory> getGameHistory({int limit = 20}) {
    return _history.reversed.take(limit).toList();
  }

  @override
  Future<void> clearAll() async {
    _history.clear();
    _stats.clear();
  }
}
