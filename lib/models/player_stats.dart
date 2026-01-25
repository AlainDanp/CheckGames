import 'package:hive/hive.dart';

part 'player_stats.g.dart';

@HiveType(typeId: 0)
class PlayerStats {
  @HiveField(0)
  final String playerName;

  @HiveField(1)
  final int gamesPlayed;

  @HiveField(2)
  final int wins;  // 1ère place

  @HiveField(3)
  final int podiums;  // top 3

  @HiveField(4)
  final Map<int, int> positionCounts;  // position → count

  @HiveField(5)
  final DateTime lastPlayed;

  PlayerStats({
    required this.playerName,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.podiums = 0,
    this.positionCounts = const {},
    DateTime? lastPlayed,
  }) : lastPlayed = lastPlayed ?? DateTime.now();

  PlayerStats copyWith({
    int? gamesPlayed,
    int? wins,
    int? podiums,
    Map<int, int>? positionCounts,
    DateTime? lastPlayed,
  }) {
    return PlayerStats(
      playerName: playerName,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      podiums: podiums ?? this.podiums,
      positionCounts: positionCounts ?? this.positionCounts,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  PlayerStats recordGame(int position) {
    final newCounts = Map<int, int>.from(positionCounts);
    newCounts[position] = (newCounts[position] ?? 0) + 1;

    return copyWith(
      gamesPlayed: gamesPlayed + 1,
      wins: position == 1 ? wins + 1 : wins,
      podiums: position <= 3 ? podiums + 1 : podiums,
      positionCounts: newCounts,
      lastPlayed: DateTime.now(),
    );
  }
}
