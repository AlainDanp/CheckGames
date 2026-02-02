import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ArcadeLeaderboardService {
  static final ArcadeLeaderboardService instance = ArcadeLeaderboardService._();
  ArcadeLeaderboardService._();

  static const String _leaderboardKey = 'arcade_leaderboard';
  static const int _maxEntries = 10;

  List<ArcadeScore> _leaderboard = [];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_leaderboardKey);

    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        _leaderboard = jsonList
            .map((json) => ArcadeScore.fromJson(json as Map<String, dynamic>))
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

  /// Retourne le classement complet (trié par score décroissant)
  List<ArcadeScore> getLeaderboard() {
    return List.from(_leaderboard)..sort((a, b) => b.score.compareTo(a.score));
  }

  /// Retourne le meilleur score
  Future<int> getBestScore() async {
    await init();
    if (_leaderboard.isEmpty) return 0;
    return _leaderboard.map((s) => s.score).reduce((a, b) => a > b ? a : b);
  }

  /// Vérifie si un score est éligible au classement
  Future<bool> isHighScore(int score) async {
    await init();
    if (score <= 0) return false;
    if (_leaderboard.length < _maxEntries) return true;

    final lowestScore = _leaderboard
        .map((s) => s.score)
        .reduce((a, b) => a < b ? a : b);

    return score > lowestScore;
  }

  /// Ajoute un score au classement
  Future<int> addScore(String name, int score) async {
    await init();

    final newScore = ArcadeScore(
      name: name.toUpperCase().substring(0, name.length.clamp(0, 3)),
      score: score,
      date: DateTime.now(),
    );

    _leaderboard.add(newScore);
    _leaderboard.sort((a, b) => b.score.compareTo(a.score));

    // Garder seulement les 10 meilleurs
    if (_leaderboard.length > _maxEntries) {
      _leaderboard = _leaderboard.sublist(0, _maxEntries);
    }

    await _save();

    // Retourner la position dans le classement (1-indexed)
    return _leaderboard.indexWhere((s) =>
            s.name == newScore.name &&
            s.score == newScore.score &&
            s.date == newScore.date) +
        1;
  }

  /// Efface tout le classement
  Future<void> clearLeaderboard() async {
    _leaderboard = [];
    await _save();
  }
}

class ArcadeScore {
  final String name;
  final int score;
  final DateTime date;

  const ArcadeScore({
    required this.name,
    required this.score,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'date': date.toIso8601String(),
      };

  factory ArcadeScore.fromJson(Map<String, dynamic> json) => ArcadeScore(
        name: json['name'] as String,
        score: json['score'] as int,
        date: DateTime.parse(json['date'] as String),
      );
}
