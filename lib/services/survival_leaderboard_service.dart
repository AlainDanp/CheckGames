import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SurvivalLeaderboardService {
  static final SurvivalLeaderboardService instance = SurvivalLeaderboardService._();
  SurvivalLeaderboardService._();

  static const String _leaderboardKey = 'survival_leaderboard';
  static const int _maxEntries = 10;

  List<SurvivalScore> _leaderboard = [];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_leaderboardKey);

    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        _leaderboard = jsonList
            .map((json) => SurvivalScore.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _leaderboard = [];
      }
    }

    _initialized = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_leaderboard.map((s) => s.toJson()).toList());
    await prefs.setString(_leaderboardKey, data);
  }

  /// Retourne le classement complet (trié par rounds décroissant)
  List<SurvivalScore> getLeaderboard() {
    return List.from(_leaderboard)..sort((a, b) => b.rounds.compareTo(a.rounds));
  }

  /// Retourne le meilleur score
  Future<int> getBestScore() async {
    await init();
    if (_leaderboard.isEmpty) return 0;
    return _leaderboard.map((s) => s.rounds).reduce((a, b) => a > b ? a : b);
  }

  /// Vérifie si un score est éligible au classement
  Future<bool> isHighScore(int rounds) async {
    await init();
    if (rounds <= 0) return false;
    if (_leaderboard.length < _maxEntries) return true;

    final lowestScore = _leaderboard
        .map((s) => s.rounds)
        .reduce((a, b) => a < b ? a : b);

    return rounds > lowestScore;
  }

  /// Ajoute un score au classement
  Future<int> addScore(String name, int rounds, String difficulty) async {
    await init();

    final newScore = SurvivalScore(
      name: name.toUpperCase().substring(0, name.length.clamp(0, 3)),
      rounds: rounds,
      maxDifficulty: difficulty,
      date: DateTime.now(),
    );

    _leaderboard.add(newScore);
    _leaderboard.sort((a, b) => b.rounds.compareTo(a.rounds));

    // Garder seulement les 10 meilleurs
    if (_leaderboard.length > _maxEntries) {
      _leaderboard = _leaderboard.sublist(0, _maxEntries);
    }

    await _save();

    // Retourner la position dans le classement (1-indexed)
    return _leaderboard.indexWhere((s) =>
            s.name == newScore.name &&
            s.rounds == newScore.rounds &&
            s.date == newScore.date) +
        1;
  }

  /// Efface tout le classement
  Future<void> clearLeaderboard() async {
    _leaderboard = [];
    await _save();
  }
}

class SurvivalScore {
  final String name;
  final int rounds;
  final String maxDifficulty;
  final DateTime date;

  const SurvivalScore({
    required this.name,
    required this.rounds,
    required this.maxDifficulty,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'rounds': rounds,
        'maxDifficulty': maxDifficulty,
        'date': date.toIso8601String(),
      };

  factory SurvivalScore.fromJson(Map<String, dynamic> json) => SurvivalScore(
        name: json['name'] as String,
        rounds: json['rounds'] as int,
        maxDifficulty: json['maxDifficulty'] as String? ?? 'Facile',
        date: DateTime.parse(json['date'] as String),
      );
}
