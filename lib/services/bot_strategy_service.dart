import 'dart:math';
import '../models/playing_card.dart';
import '../models/card_value.dart';
import '../models/card_suit.dart';
import '../models/player_card.dart';
import '../logic/rule_engine.dart';
import 'game_settings_service.dart';

/// Service de stratégie pour les bots selon le niveau de difficulté
class BotStrategyService {
  static final BotStrategyService _instance = BotStrategyService._internal();
  factory BotStrategyService() => _instance;
  BotStrategyService._internal();

  static BotStrategyService get instance => _instance;

  final Random _random = Random();

  /// Décide si le bot doit contrer une attaque (7 ou Joker)
  /// Retourne la carte à jouer ou null si le bot subit l'attaque
  PlayingCard? decideCounterAttack({
    required List<PlayingCard> hand,
    required PlayingCard topCard,
    required CardSuit? imposedSuit,
    required int cardsToDraw,
  }) {
    final difficulty = GameSettingsService.instance.difficulty;

    // Trouver les cartes de contre possibles
    final counters = hand.where((c) =>
      (c.value == CardValue.seven || c.value == CardValue.joker) &&
      RuleEngine.canPlayCard(
        cardToPlay: c,
        topCard: topCard,
        imposedSuit: imposedSuit,
      )
    ).toList();

    if (counters.isEmpty) return null;

    switch (difficulty) {
      case BotDifficulty.easy:
        // En facile : 40% de chance de contrer seulement
        if (_random.nextDouble() < 0.4) {
          return counters[_random.nextInt(counters.length)];
        }
        return null; // Subit l'attaque

      case BotDifficulty.normal:
        // En normal : contre toujours si possible
        return counters.first;

      case BotDifficulty.hard:
        // En difficile : contre intelligemment
        // Préfère le 7 si le cumul est faible, le Joker si élevé
        if (cardsToDraw >= 4) {
          // Cherche un Joker pour renvoyer plus
          final joker = counters.where((c) => c.value == CardValue.joker).firstOrNull;
          if (joker != null) return joker;
        }
        // Sinon utilise un 7 (moins puissant)
        final seven = counters.where((c) => c.value == CardValue.seven).firstOrNull;
        return seven ?? counters.first;
    }
  }

  /// Sélectionne la meilleure carte à jouer selon la difficulté
  PlayingCard selectCardToPlay({
    required List<PlayingCard> hand,
    required List<PlayingCard> playableCards,
    required List<Player> allPlayers,
    required int currentPlayerIndex,
  }) {
    final difficulty = GameSettingsService.instance.difficulty;

    switch (difficulty) {
      case BotDifficulty.easy:
        return _selectCardEasy(playableCards);

      case BotDifficulty.normal:
        return _selectCardNormal(playableCards, hand);

      case BotDifficulty.hard:
        return _selectCardHard(playableCards, hand, allPlayers, currentPlayerIndex);
    }
  }

  /// Mode Facile : choix aléatoire
  PlayingCard _selectCardEasy(List<PlayingCard> playableCards) {
    return playableCards[_random.nextInt(playableCards.length)];
  }

  /// Mode Normal : évite de jouer les cartes spéciales en premier
  PlayingCard _selectCardNormal(List<PlayingCard> playableCards, List<PlayingCard> hand) {
    // Séparer les cartes normales et spéciales
    final normalCards = playableCards.where((c) => !_isSpecialCard(c)).toList();
    final specialCards = playableCards.where((c) => _isSpecialCard(c)).toList();

    // Préférer les cartes normales
    if (normalCards.isNotEmpty) {
      return normalCards.first;
    }

    // Si on n'a que des spéciales, jouer la moins puissante
    if (specialCards.isNotEmpty) {
      return _leastPowerfulSpecial(specialCards);
    }

    return playableCards.first;
  }

  /// Mode Difficile : stratégie avancée
  PlayingCard _selectCardHard(
    List<PlayingCard> playableCards,
    List<PlayingCard> hand,
    List<Player> allPlayers,
    int currentPlayerIndex,
  ) {
    // Trouver le joueur suivant
    final nextPlayerIndex = (currentPlayerIndex + 1) % allPlayers.length;
    final nextPlayer = allPlayers[nextPlayerIndex];
    final nextPlayerCardCount = nextPlayer.hand.length;

    // Si le joueur suivant a peu de cartes, essayer de l'attaquer
    if (nextPlayerCardCount <= 2) {
      // Chercher un 7 ou Joker pour l'attaquer
      final attackCards = playableCards.where((c) =>
        c.value == CardValue.seven || c.value == CardValue.joker
      ).toList();

      if (attackCards.isNotEmpty) {
        // Préférer le 7 pour forcer à piocher
        final seven = attackCards.where((c) => c.value == CardValue.seven).firstOrNull;
        if (seven != null) return seven;
        return attackCards.first;
      }
    }

    // Si on a peu de cartes (3 ou moins), garder les cartes spéciales
    if (hand.length <= 3) {
      final normalCards = playableCards.where((c) => !_isSpecialCard(c)).toList();
      if (normalCards.isNotEmpty) {
        // Jouer la carte de la couleur qu'on a le plus
        return _cardOfMostCommonSuit(normalCards, hand);
      }
    }

    // Stratégie par défaut : jouer la carte qui garde le plus d'options
    return _selectCardNormal(playableCards, hand);
  }

  /// Décide si le bot doit jouer plusieurs cartes de même valeur
  List<PlayingCard> decideMultipleCards({
    required PlayingCard selectedCard,
    required List<PlayingCard> hand,
  }) {
    final difficulty = GameSettingsService.instance.difficulty;
    final sameValueCards = hand.where((c) =>
      c.value == selectedCard.value && c != selectedCard
    ).toList();

    if (sameValueCards.isEmpty) return [selectedCard];

    switch (difficulty) {
      case BotDifficulty.easy:
        // En facile : 30% de chance de jouer les doubles
        if (_random.nextDouble() < 0.3) {
          return [selectedCard, ...sameValueCards];
        }
        return [selectedCard];

      case BotDifficulty.normal:
        // En normal : joue toujours les doubles
        return [selectedCard, ...sameValueCards];

      case BotDifficulty.hard:
        // En difficile : joue les doubles sauf pour les cartes spéciales
        if (_isSpecialCard(selectedCard)) {
          // Garde les spéciales pour plus tard
          return [selectedCard];
        }
        return [selectedCard, ...sameValueCards];
    }
  }

  /// Choisit la couleur à imposer pour un Valet
  CardSuit selectImposedSuit({
    required List<PlayingCard> hand,
    required List<Player> allPlayers,
    required int currentPlayerIndex,
  }) {
    final difficulty = GameSettingsService.instance.difficulty;

    switch (difficulty) {
      case BotDifficulty.easy:
        // En facile : couleur aléatoire
        final suits = [CardSuit.hearts, CardSuit.diamonds, CardSuit.clubs, CardSuit.spades];
        return suits[_random.nextInt(suits.length)];

      case BotDifficulty.normal:
        // En normal : couleur qu'on a le plus
        return _mostCommonSuit(hand);

      case BotDifficulty.hard:
        // En difficile : couleur qu'on a le plus, mais éviter de donner un avantage
        return _mostCommonSuit(hand);
    }
  }

  /// Vérifie si une carte est spéciale
  bool _isSpecialCard(PlayingCard card) {
    return card.value == CardValue.two ||
           card.value == CardValue.seven ||
           card.value == CardValue.jack ||
           card.value == CardValue.ace ||
           card.value == CardValue.joker;
  }

  /// Retourne la carte spéciale la moins puissante
  PlayingCard _leastPowerfulSpecial(List<PlayingCard> specialCards) {
    // Ordre de puissance : 2 < As < Valet < 7 < Joker
    final priority = {
      CardValue.two: 1,
      CardValue.ace: 2,
      CardValue.jack: 3,
      CardValue.seven: 4,
      CardValue.joker: 5,
    };

    specialCards.sort((a, b) =>
      (priority[a.value] ?? 0).compareTo(priority[b.value] ?? 0)
    );

    return specialCards.first;
  }

  /// Retourne la couleur la plus commune dans la main
  CardSuit _mostCommonSuit(List<PlayingCard> hand) {
    final counts = <CardSuit, int>{
      CardSuit.hearts: 0,
      CardSuit.diamonds: 0,
      CardSuit.clubs: 0,
      CardSuit.spades: 0,
    };

    for (final c in hand) {
      if (counts.containsKey(c.suit)) {
        counts[c.suit] = (counts[c.suit] ?? 0) + 1;
      }
    }

    CardSuit bestSuit = CardSuit.hearts;
    int maxCount = -1;

    counts.forEach((suit, count) {
      if (count > maxCount) {
        maxCount = count;
        bestSuit = suit;
      }
    });

    return bestSuit;
  }

  /// Retourne la carte de la couleur la plus commune
  PlayingCard _cardOfMostCommonSuit(List<PlayingCard> cards, List<PlayingCard> hand) {
    final mostCommon = _mostCommonSuit(hand);

    final suitCards = cards.where((c) => c.suit == mostCommon).toList();
    if (suitCards.isNotEmpty) {
      return suitCards.first;
    }

    return cards.first;
  }
}
