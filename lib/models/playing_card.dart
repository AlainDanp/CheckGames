import 'card_suit.dart';
import 'card_value.dart';

class PlayingCard {
  final CardSuit suit;
  final CardValue value;

  const PlayingCard({
    required this.suit,
    required this.value,
  });

  @override
  String toString() => '${value.label}${suit.symbol}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PlayingCard &&
              runtimeType == other.runtimeType &&
              suit == other.suit &&
              value == other.value;

  @override
  int get hashCode => suit.hashCode ^ value.hashCode;
}
