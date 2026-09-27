import '../models/card_suit.dart';
import '../models/card_value.dart';
import '../models/playing_card.dart';
import '../utils/app_logger.dart';

class DeckGenerator {
  /// Génère un paquet de 52 cartes + 2 jokers (54)
  static List<PlayingCard> generateFullDeck({bool includeJokers = true}) {
    final List<PlayingCard> deck = [];

    // Ne pas inclure les jokers ici
    const normalSuits = [
      CardSuit.hearts, CardSuit.diamonds, CardSuit.clubs, CardSuit.spades,
    ];

    for (final suit in normalSuits) {
      for (final value in CardValue.values) {
        if (value == CardValue.joker) continue;
        deck.add(PlayingCard(suit: suit, value: value));
      }
    }

    // Ajouter les jokers (sans couleur)
    if (includeJokers) {
      deck.add(const PlayingCard(suit: CardSuit.jokerRed,   value: CardValue.joker));
      deck.add(const PlayingCard(suit: CardSuit.jokerBlack, value: CardValue.joker));
    }

    // Vérification stricte : lancer une exception si doublons détectés
    if (!_checkUnique(deck)) {
      throw StateError(
        'ERREUR CRITIQUE: Le deck contient des doublons! '
        'Nombre de cartes: ${deck.length}, '
        'Nombre de cartes uniques: ${deck.toSet().length}'
      );
    }

    // Vérifier le nombre de cartes attendu
    final expectedCount = includeJokers ? 54 : 52;
    if (deck.length != expectedCount) {
      throw StateError(
        'ERREUR CRITIQUE: Nombre de cartes incorrect! '
        'Attendu: $expectedCount, Obtenu: ${deck.length}'
      );
    }

    return deck;
  }

  /// Mélange le deck
  static List<PlayingCard> shuffledDeck({bool includeJokers = true}) {
    final deck = generateFullDeck(includeJokers: includeJokers);
    deck.shuffle();
    return deck;
  }

  /// Vérifie l'unicité des cartes dans le deck
  static bool _checkUnique(List<PlayingCard> cards) {
    final seen = <String>{};
    final duplicates = <String>[];

    for (final c in cards) {
      final key = '${c.suit.name}-${c.value.name}';
      if (!seen.add(key)) {
        duplicates.add(key);
      }
    }

    if (duplicates.isNotEmpty) {
      appLogger.w('Doublons détectés dans le deck: ${duplicates.join(', ')}');
      return false;
    }

    return true;
  }

  /// Méthode de débogage pour vérifier le contenu du deck
  static void debugDeck() {
    final deck = generateFullDeck(includeJokers: true);
    final groups = <CardSuit, List<PlayingCard>>{};
    for (final card in deck) {
      groups.putIfAbsent(card.suit, () => []).add(card);
    }

    final repartition = groups.entries.map((e) => '${e.key.name}: ${e.value.length}').join(', ');
    appLogger.d('Deck — total: ${deck.length}, uniques: ${deck.toSet().length}, valide: ${_checkUnique(deck)}, répartition: $repartition');
  }
}
