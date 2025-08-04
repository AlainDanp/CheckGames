import 'playing_card.dart';

class Player {
  final String id;
  final String name;
  final List<PlayingCard> hand;

  Player({
    required this.id,
    required this.name,
    this.hand = const [],
  });

  Player copyWith({
    String? id,
    String? name,
    List<PlayingCard>? hand,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? this.hand,
    );
  }
}
