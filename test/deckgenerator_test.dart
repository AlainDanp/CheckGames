import 'package:flutter_test/flutter_test.dart';
import 'package:checkgame/logic/deckgenerator.dart';
import 'package:checkgame/models/card_suit.dart';
import 'package:checkgame/models/card_value.dart';
import 'package:checkgame/models/playing_card.dart';

void main() {
  group('DeckGenerator - Vérification de l\'unicité', () {
    test('Le deck doit contenir exactement 54 cartes uniques (avec jokers)', () {
      final deck = DeckGenerator.generateFullDeck(includeJokers: true);

      // Vérifier le nombre total
      expect(deck.length, 54, reason: 'Un deck standard contient 52 cartes + 2 jokers');

      // Vérifier qu'il n'y a pas de doublons
      final uniqueCards = deck.toSet();
      expect(uniqueCards.length, 54, reason: 'Toutes les cartes doivent être uniques');
      expect(deck.length, uniqueCards.length, reason: 'Aucun doublon ne doit exister');
    });

    test('Le deck doit contenir exactement 52 cartes uniques (sans jokers)', () {
      final deck = DeckGenerator.generateFullDeck(includeJokers: false);

      // Vérifier le nombre total
      expect(deck.length, 52, reason: 'Un deck standard contient 52 cartes sans jokers');

      // Vérifier qu'il n'y a pas de doublons
      final uniqueCards = deck.toSet();
      expect(uniqueCards.length, 52, reason: 'Toutes les cartes doivent être uniques');
    });

    test('Chaque couleur doit avoir exactement 13 cartes (As à Roi)', () {
      final deck = DeckGenerator.generateFullDeck(includeJokers: false);

      final hearts = deck.where((c) => c.suit == CardSuit.hearts).toList();
      final diamonds = deck.where((c) => c.suit == CardSuit.diamonds).toList();
      final clubs = deck.where((c) => c.suit == CardSuit.clubs).toList();
      final spades = deck.where((c) => c.suit == CardSuit.spades).toList();

      expect(hearts.length, 13, reason: 'Cœur doit avoir 13 cartes');
      expect(diamonds.length, 13, reason: 'Carreau doit avoir 13 cartes');
      expect(clubs.length, 13, reason: 'Trèfle doit avoir 13 cartes');
      expect(spades.length, 13, reason: 'Pique doit avoir 13 cartes');
    });

    test('Il doit y avoir exactement 2 jokers distincts (rouge et noir)', () {
      final deck = DeckGenerator.generateFullDeck(includeJokers: true);

      final jokers = deck.where((c) => c.value == CardValue.joker).toList();

      expect(jokers.length, 2, reason: 'Il doit y avoir exactement 2 jokers');

      final jokerRed = jokers.where((c) => c.suit == CardSuit.jokerRed).toList();
      final jokerBlack = jokers.where((c) => c.suit == CardSuit.jokerBlack).toList();

      expect(jokerRed.length, 1, reason: 'Il doit y avoir 1 joker rouge');
      expect(jokerBlack.length, 1, reason: 'Il doit y avoir 1 joker noir');
    });

    test('Aucune carte ne doit apparaître plus d\'une fois', () {
      final deck = DeckGenerator.generateFullDeck(includeJokers: true);

      final cardCounts = <String, int>{};
      for (final card in deck) {
        final key = '${card.suit.name}-${card.value.name}';
        cardCounts[key] = (cardCounts[key] ?? 0) + 1;
      }

      // Vérifier qu'aucune carte n'apparaît plus d'une fois
      final duplicates = cardCounts.entries.where((e) => e.value > 1).toList();
      expect(duplicates, isEmpty,
        reason: 'Doublons détectés: ${duplicates.map((e) => '${e.key} (x${e.value})').join(', ')}');
    });

    test('Toutes les valeurs de As à Roi doivent être présentes pour chaque couleur', () {
      final deck = DeckGenerator.generateFullDeck(includeJokers: false);

      final normalSuits = [CardSuit.hearts, CardSuit.diamonds, CardSuit.clubs, CardSuit.spades];
      final normalValues = CardValue.values.where((v) => v != CardValue.joker).toList();

      for (final suit in normalSuits) {
        for (final value in normalValues) {
          final card = PlayingCard(suit: suit, value: value);
          expect(deck.contains(card), true,
            reason: 'La carte $card devrait être dans le deck');
        }
      }
    });

    test('Le deck mélangé doit contenir les mêmes cartes uniques', () {
      final deck1 = DeckGenerator.generateFullDeck(includeJokers: true);
      final deck2 = DeckGenerator.shuffledDeck(includeJokers: true);

      expect(deck2.length, deck1.length);
      expect(deck2.toSet(), deck1.toSet(),
        reason: 'Le deck mélangé doit contenir exactement les mêmes cartes');
    });

    test('Plusieurs générations de deck doivent être identiques (avant mélange)', () {
      final deck1 = DeckGenerator.generateFullDeck(includeJokers: true);
      final deck2 = DeckGenerator.generateFullDeck(includeJokers: true);
      final deck3 = DeckGenerator.generateFullDeck(includeJokers: true);

      expect(deck1.toSet(), deck2.toSet());
      expect(deck2.toSet(), deck3.toSet());
    });
  });
}
