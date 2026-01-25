import 'package:hive/hive.dart';

part 'game_history.g.dart';

@HiveType(typeId: 1)
class GameHistory {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final List<String> playerNames;

  @HiveField(2)
  final List<String> finishingOrder;  // IDs dans l'ordre

  @HiveField(3)
  final bool hadDuel;

  GameHistory({
    required this.date,
    required this.playerNames,
    required this.finishingOrder,
    this.hadDuel = false,
  });
}
