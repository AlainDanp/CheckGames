import '../models/card_suit.dart';
import '../models/card_value.dart';
import '../models/playing_card.dart';

class DeckGenerator {
  /// Génère un paquet de 52 cartes + 2 jokers (54)
  static List<PlayingCard> generateFullDeck({bool includeJokers = true}) {
    final List<PlayingCard> deck = [];

    for (final suit in CardSuit.values) {
      if (suit == CardSuit.joker) continue;

      for (final value in CardValue.values) {
        if (value != CardValue.joker) {
          deck.add(PlayingCard(suit: suit, value: value));
        }
      }
    }
    // Ajouter les jokers (sans couleur)
    if (includeJokers) {
      deck.add(const PlayingCard(suit: CardSuit.joker, value: CardValue.joker)); // Joker noir
      deck.add(const PlayingCard(suit: CardSuit.joker, value: CardValue.joker)); // Joker rouge
    }

    return deck;
  }

  /// Mélange le deck
  static List<PlayingCard> shuffledDeck({bool includeJokers = true}) {
    final deck = generateFullDeck(includeJokers: includeJokers);
    deck.shuffle();
    return deck;
  }
}
