import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/playing_card.dart';
import '../models/card_suit.dart';
import '../models/card_value.dart';
import '../logic/rule_engine.dart';

/// Service responsable de l'exécution des actions de jeu via transactions atomiques
/// Toutes les modifications d'état passent par ce service pour garantir la cohérence
class GameActionService {
  final FirebaseFirestore _firestore;

  GameActionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Joue une ou plusieurs cartes
  /// Utilise une transaction atomique pour garantir la validité de l'action
  Future<void> playCard({
    required String roomId,
    required String playerId,
    required List<PlayingCard> cards,
    CardSuit? imposedSuit, // Pour le Valet
  }) async {
    print('🎮 GameActionService: Joueur $playerId joue ${cards.length} carte(s)');

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Lire l'état actuel
        final roomDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId),
        );
        final gameStateDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
        );
        final handDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('player_hands').doc(playerId),
        );

        if (!roomDoc.exists || !gameStateDoc.exists || !handDoc.exists) {
          throw Exception('Données de jeu introuvables');
        }

        final roomData = roomDoc.data()!;
        final gameStateData = gameStateDoc.data()!;
        final handData = handDoc.data()!;

        // 2. Vérifier que c'est le tour du joueur
        final currentPlayerId = roomData['currentPlayerId'] as String;
        if (currentPlayerId != playerId) {
          throw Exception('Ce n\'est pas votre tour !');
        }

        // 3. Récupérer et valider la main du joueur
        final hand = (handData['cards'] as List)
            .map((c) => _jsonToCard(c as Map<String, dynamic>))
            .toList();

        // Vérifier que le joueur possède toutes les cartes qu'il veut jouer
        for (final card in cards) {
          if (!hand.contains(card)) {
            throw Exception('Vous ne possédez pas cette carte: $card');
          }
        }

        // 4. Vérifier que la carte peut être jouée
        final discardPile = (gameStateData['discardPile'] as List)
            .map((c) => _jsonToCard(c as Map<String, dynamic>))
            .toList();

        if (discardPile.isEmpty) {
          throw Exception('Pile de défausse vide');
        }

        PlayingCard virtualTopCard = discardPile.last;
        CardSuit? virtualImposedSuit = roomData['imposedSuit'] != null
        ? CardSuit.values[roomData['imposedSuit'] as int] : null;
        int virtualPendingDraw = roomData['cardsToDraw'] as int;

        // Valider chaque carte
        for (int i = 0; i < cards.length; i++) {
          final card = cards[i];
          if (!RuleEngine.canPlayCard(
            cardToPlay: card,
            topCard: virtualTopCard,
            imposedSuit: virtualImposedSuit,
            pendingDraw: virtualPendingDraw,
          )) {
            throw Exception('La carte ${card.value} de ${card.suit} ne peut pas être jouée ici.');
          }
          virtualTopCard = card;
          virtualImposedSuit = null;
          virtualPendingDraw = 0;
        }

        // 5. Retirer les cartes de la main du joueur
        final newHand = hand.where((c) => !cards.contains(c)).toList();

        // 6. Ajouter les cartes à la défausse
        final newDiscardPile = [...discardPile, ...cards];

        // 7. Calculer les effets des cartes jouées
        final effects = _calculateEffects(cards, imposedSuit);

        // 8. Calculer le prochain joueur
        final playerOrder = List<String>.from(gameStateData['playerOrder']);
        final direction = roomData['direction'] as int;
        final currentSkipCount = roomData['skipCount'] as int;

        print('🎮 Calcul du prochain joueur:');
        print('  - playerOrder: $playerOrder');
        print('  - currentPlayerId: $playerId');
        print('  - direction: $direction');
        print('  - skipCount from effects: ${effects['skipCount']}');

        final nextPlayerInfo = _getNextPlayer(
          playerOrder: playerOrder,
          currentPlayerId: playerId,
          direction: direction,
          additionalSkips: effects['skipCount'] as int,
        );

        print('  - nextPlayerId: ${nextPlayerInfo['playerId']}');

        // 9. Vérifier si le joueur a gagné (main vide)
        final hasWon = newHand.isEmpty;
        final finishingOrder = List<String>.from(gameStateData['finishingOrder'] ?? []);
        if (hasWon && !finishingOrder.contains(playerId)) {
          finishingOrder.add(playerId);
          print('🏆 Joueur $playerId a terminé ! Position: ${finishingOrder.length}');
        }

        // Calculer les joueurs encore en jeu
        final activePlayerIds = playerOrder.where((id) => !finishingOrder.contains(id)).toList();
        final activePlayers = activePlayerIds.length;

        print('📊 Joueurs actifs: $activePlayers / ${playerOrder.length}');

        // Vérifier si la partie est terminée (1 seul joueur restant ou moins)
        bool isGameOver = false;
        String? gamePhase;

        if (activePlayers <= 1) {
          // GAME OVER - Ajouter le dernier joueur à l'ordre de finition
          if (activePlayers == 1 && !finishingOrder.contains(activePlayerIds.first)) {
            finishingOrder.add(activePlayerIds.first);
            print('🏁 Dernier joueur ajouté: ${activePlayerIds.first}');
          }
          isGameOver = true;
          gamePhase = 'finished';
          print('🎉 PARTIE TERMINÉE ! Ordre final: $finishingOrder');
        } else if (activePlayers == 2) {
          // Phase DUEL (2 joueurs restants)
          final currentPhase = roomData['phase'] as String? ?? 'normal';
          if (currentPhase != 'duel') {
            gamePhase = 'duel';
            print('⚔️ DUEL déclenché entre les 2 derniers joueurs !');
          }
        }



        // 10. Mettre à jour Firestore (atomique)
        print('🎮 Mise à jour Firestore: currentPlayerId -> ${nextPlayerInfo['playerId']}');

        final roomUpdate = {
          'currentPlayerId': nextPlayerInfo['playerId'],
          'direction': effects['direction'] ?? direction,
          'skipCount': currentSkipCount + (effects['skipCount'] as int),
          'cardsToDraw': (roomData['cardsToDraw'] as int) + (effects['cardsToDraw'] as int),
          'imposedSuit': effects['imposedSuit'] != null
              ? (effects['imposedSuit'] as CardSuit).index
              : null,
          'isGameOver': isGameOver,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Ajouter la phase si elle a changé
        if (gamePhase != null) {
          roomUpdate['phase'] = gamePhase;
        }

        transaction.update(
          _firestore.collection('game_rooms').doc(roomId),
          roomUpdate,
        );

        print('🎮 Transaction update appelé pour room $roomId');

        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
          {
            'discardPile': newDiscardPile.map(_cardToJson).toList(),
            'finishingOrder': finishingOrder,
            'lastAction': {
              'playerId': playerId,
              'type': 'play_card',
              'timestamp': FieldValue.serverTimestamp(),
            },
          },
        );

        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('player_hands').doc(playerId),
          {
            'cards': newHand.map(_cardToJson).toList(),
          },
        );

        // Mettre à jour le handSize public pour que les autres joueurs le voient
        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('players').doc(playerId),
          {
            'handSize': newHand.length,
          },
        );

        // 11. Logger l'action
        transaction.set(
          _firestore.collection('game_rooms').doc(roomId).collection('actions').doc(),
          {
            'playerId': playerId,
            'type': 'play_card',
            'data': {
              'cards': cards.map(_cardToJson).toList(),
              'imposedSuit': imposedSuit?.index,
            },
            'timestamp': FieldValue.serverTimestamp(),
          },
        );

        print('✅ GameActionService: Transaction réussie - Carte(s) jouée(s)');
      });

      print('✅ ========================================');
      print('✅ GameActionService: SUCCÈS COMPLET');
      print('✅ Firebase a été mis à jour avec:');
      print('✅   - Nouveau currentPlayerId (tous les listeners vont recevoir la mise à jour)');
      print('✅   - Nouvelle défausse');
      print('✅   - Main du joueur mise à jour');
      print('✅ ========================================');
    } catch (e) {
      print('❌ ========================================');
      print('❌ GameActionService: ÉCHEC');
      print('❌ Erreur lors du jeu de la carte: $e');
      print('❌ ========================================');
      rethrow;
    }
  }

  /// Piocher des cartes
  Future<void> drawCard({
    required String roomId,
    required String playerId,
    int count = 1,
  }) async {
    print('🎮 GameActionService: Joueur $playerId pioche $count carte(s)');

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Lire l'état actuel
        final roomDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId),
        );
        final deckDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('deck'),
        );
        final gameStateDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
        );
        final handDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('player_hands').doc(playerId),
        );

        if (!roomDoc.exists || !deckDoc.exists || !gameStateDoc.exists || !handDoc.exists) {
          throw Exception('Données de jeu introuvables');
        }

        final roomData = roomDoc.data()!;
        final deckData = deckDoc.data()!;
        final handData = handDoc.data()!;

        // 2. Vérifier que c'est le tour du joueur
        final currentPlayerId = roomData['currentPlayerId'] as String;
        if (currentPlayerId != playerId) {
          throw Exception('Ce n\'est pas votre tour !');
        }

        // 3. Récupérer le deck et la main
        var deck = (deckData['cards'] as List)
            .map((c) => _jsonToCard(c as Map<String, dynamic>))
            .toList();
        final hand = (handData['cards'] as List)
            .map((c) => _jsonToCard(c as Map<String, dynamic>))
            .toList();

        // 4. Vérifier qu'il y a assez de cartes
        if (deck.length < count) {
          // Si pas assez, mélanger la défausse dans le deck
          final gameStateData = gameStateDoc.data()!;
          final discardPile = (gameStateData['discardPile'] as List)
              .map((c) => _jsonToCard(c as Map<String, dynamic>))
              .toList();

          if (discardPile.length > 1) {
            // Garder la dernière carte de la défausse
            final topCard = discardPile.last;
            final cardsToShuffle = discardPile.sublist(0, discardPile.length - 1);
            cardsToShuffle.shuffle();
            deck.addAll(cardsToShuffle);

            // Mettre à jour la défausse
            transaction.update(
              _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
              {
                'discardPile': [_cardToJson(topCard)],
              },
            );
          }

          if (deck.length < count) {
            throw Exception('Pas assez de cartes disponibles (même après recyclage)');
          }
        }

        // 5. Piocher les cartes
        final drawnCards = deck.take(count).toList();
        final remainingDeck = deck.skip(count).toList();

        // 6. Ajouter à la main
        final newHand = [...hand, ...drawnCards];

        // 7. Mettre à jour Firestore
        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('deck'),
          {
            'cards': remainingDeck.map(_cardToJson).toList(),
          },
        );

        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
          {
            'deckSize': remainingDeck.length,
          },
        );

        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('player_hands').doc(playerId),
          {
            'cards': newHand.map(_cardToJson).toList(),
          },
        );

        // Mettre à jour le handSize public
        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('players').doc(playerId),
          {
            'handSize': newHand.length,
          },
        );

        // Réinitialiser cardsToDraw si la pioche était obligatoire
        final cardsToDraw = roomData['cardsToDraw'] as int;
        if (cardsToDraw > 0) {
          transaction.update(
            _firestore.collection('game_rooms').doc(roomId),
            {
              'cardsToDraw': 0,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }

        // 8. AUTOMATIQUEMENT PASSER LE TOUR (comme en mode solo)
        // IMPORTANT : Piocher annule les effets de skip (As)
        // On passe au joueur suivant SANS appliquer skipCount
        final gameStateData = gameStateDoc.data()!;
        final playerOrder = List<String>.from(gameStateData['playerOrder']);
        final direction = roomData['direction'] as int;

        final nextPlayerInfo = _getNextPlayer(
          playerOrder: playerOrder,
          currentPlayerId: playerId,
          direction: direction,
          additionalSkips: 0, // ⭐ Toujours 0 : piocher passe normalement le tour
        );

        transaction.update(
          _firestore.collection('game_rooms').doc(roomId),
          {
            'currentPlayerId': nextPlayerInfo['playerId'],
            'skipCount': 0, // ⭐ Réinitialiser le skipCount de l'As
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        print('🔄 Tour passé automatiquement au joueur: ${nextPlayerInfo['playerId']}');

        // 9. Logger l'action
        transaction.set(
          _firestore.collection('game_rooms').doc(roomId).collection('actions').doc(),
          {
            'playerId': playerId,
            'type': 'draw_card',
            'data': {'count': count},
            'timestamp': FieldValue.serverTimestamp(),
          },
        );

        print('✅ GameActionService: Carte(s) piochée(s) avec succès');
      });
    } catch (e) {
      print('❌ GameActionService: Erreur lors de la pioche: $e');
      rethrow;
    }
  }

  /// Passer son tour (après avoir pioché si nécessaire)
  Future<void> endTurn({
    required String roomId,
    required String playerId,
  }) async {
    print('🎮 GameActionService: Joueur $playerId passe son tour');

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Lire l'état actuel
        final roomDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId),
        );
        final gameStateDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
        );
        final deckDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('deck'),
        );
        final handDoc = await transaction.get(
          _firestore.collection('game_rooms').doc(roomId).collection('player_hands').doc(playerId),
        );

        if (!roomDoc.exists || !gameStateDoc.exists || !deckDoc.exists || !handDoc.exists) {
          throw Exception('Données de jeu introuvables');
        }

        final roomData = roomDoc.data()!;
        final gameStateData = gameStateDoc.data()!;
        final deckData = deckDoc.data()!;
        final handData = handDoc.data()!;

        // 2. Vérifier que c'est le tour du joueur
        final currentPlayerId = roomData['currentPlayerId'] as String;
        if (currentPlayerId != playerId) {
          throw Exception('Ce n\'est pas votre tour !');
        }

        // 3. GESTION DU CUMULUS : Si cardsToDraw > 0, appliquer la pénalité
        final cardsToDraw = roomData['cardsToDraw'] as int;

        if (cardsToDraw > 0) {
          print('🎲 Application de la pénalité cumulus: $cardsToDraw cartes à piocher');

          // Récupérer le deck et la main
          var deck = (deckData['cards'] as List)
              .map((c) => _jsonToCard(c as Map<String, dynamic>))
              .toList();
          final hand = (handData['cards'] as List)
              .map((c) => _jsonToCard(c as Map<String, dynamic>))
              .toList();

          // Vérifier qu'il y a assez de cartes
          if (deck.length < cardsToDraw) {
            // Recycler la défausse si nécessaire
            final discardPile = (gameStateData['discardPile'] as List)
                .map((c) => _jsonToCard(c as Map<String, dynamic>))
                .toList();

            if (discardPile.length > 1) {
              final topCard = discardPile.last;
              final cardsToShuffle = discardPile.sublist(0, discardPile.length - 1);
              cardsToShuffle.shuffle();
              deck.addAll(cardsToShuffle);

              // Mettre à jour la défausse
              transaction.update(
                _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
                {
                  'discardPile': [_cardToJson(topCard)],
                },
              );
            }
          }

          // Piocher les cartes de pénalité
          final drawnCards = deck.take(cardsToDraw).toList();
          final remainingDeck = deck.skip(cardsToDraw).toList();
          final newHand = [...hand, ...drawnCards];

          print('✅ Pénalité appliquée: ${drawnCards.length} cartes piochées');

          // Mettre à jour le deck et la main
          transaction.update(
            _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('deck'),
            {
              'cards': remainingDeck.map(_cardToJson).toList(),
            },
          );

          transaction.update(
            _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
            {
              'deckSize': remainingDeck.length,
            },
          );

          transaction.update(
            _firestore.collection('game_rooms').doc(roomId).collection('player_hands').doc(playerId),
            {
              'cards': newHand.map(_cardToJson).toList(),
            },
          );

          transaction.update(
            _firestore.collection('game_rooms').doc(roomId).collection('players').doc(playerId),
            {
              'handSize': newHand.length,
            },
          );

          // Réinitialiser cardsToDraw après application
          transaction.update(
            _firestore.collection('game_rooms').doc(roomId),
            {
              'cardsToDraw': 0,
            },
          );
        }

        // 4. Calculer le prochain joueur
        final playerOrder = List<String>.from(gameStateData['playerOrder']);
        final direction = roomData['direction'] as int;
        final skipCount = roomData['skipCount'] as int;

        final nextPlayerInfo = _getNextPlayer(
          playerOrder: playerOrder,
          currentPlayerId: playerId,
          direction: direction,
          additionalSkips: skipCount,
        );

        // 5. Mettre à jour le joueur actuel
        transaction.update(
          _firestore.collection('game_rooms').doc(roomId),
          {
            'currentPlayerId': nextPlayerInfo['playerId'],
            'skipCount': 0, // Réinitialiser après avoir appliqué
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
          {
            'lastAction': {
              'playerId': playerId,
              'type': 'end_turn',
              'timestamp': FieldValue.serverTimestamp(),
            },
          },
        );

        // 6. Logger l'action
        transaction.set(
          _firestore.collection('game_rooms').doc(roomId).collection('actions').doc(),
          {
            'playerId': playerId,
            'type': 'end_turn',
            'data': {'cumulusApplied': cardsToDraw > 0, 'cardsDrawn': cardsToDraw},
            'timestamp': FieldValue.serverTimestamp(),
          },
        );

        print('✅ GameActionService: Tour terminé avec succès');
      });
    } catch (e) {
      print('❌ GameActionService: Erreur lors de la fin du tour: $e');
      rethrow;
    }
  }

  /// Calcule les effets des cartes jouées
  Map<String, dynamic> _calculateEffects(List<PlayingCard> cards, CardSuit? imposedSuit) {
    int skipCount = 0;
    int cardsToDraw = 0;
    int? direction;
    CardSuit? imposedSuitResult;

    for (final card in cards) {
      switch (card.value) {
        case CardValue.ace:
          skipCount += 1; // Passe le joueur suivant
          break;
        case CardValue.seven:
          cardsToDraw += 2; // Le suivant doit piocher 2
          break;
        case CardValue.joker:
          cardsToDraw += 4; // Le suivant doit piocher 4
          break;
        case CardValue.jack:
          // Impose une couleur (fournie en paramètre)
          if (imposedSuit != null) {
            imposedSuitResult = imposedSuit;
          }
          break;
        case CardValue.two:
          // Wildcard - peut être joué sur n'importe quoi
          // Pas d'effet spécial
          break;
        default:
          // Pas d'effet
          break;
      }
    }

    return {
      'skipCount': skipCount,
      'cardsToDraw': cardsToDraw,
      'direction': direction,
      'imposedSuit': imposedSuitResult,
    };
  }

  /// Calcule le prochain joueur dans la liste circulaire
  ///
  /// Système de tour par tour :
  /// 1. playerOrder = [hôte, joueur2, joueur3, ...] (fixe, créé à l'init)
  /// 2. On avance dans la liste : index 0 → 1 → 2 → ... → 0 (circulaire)
  /// 3. direction = 1 (horaire) ou -1 (anti-horaire)
  /// 4. additionalSkips = nombre de joueurs à sauter (As = skip 1)
  Map<String, dynamic> _getNextPlayer({
    required List<String> playerOrder,
    required String currentPlayerId,
    required int direction,
    int additionalSkips = 0,
  }) {
    final currentIndex = playerOrder.indexOf(currentPlayerId);
    if (currentIndex == -1) {
      throw Exception('Joueur actuel introuvable dans playerOrder');
    }

    // Calculer le nombre total de positions à avancer (1 normal + skips)
    final totalSteps = 1 + additionalSkips;

    // Avancer dans la liste circulaire
    int newIndex = (currentIndex + (direction * totalSteps)) % playerOrder.length;

    // Gérer les indices négatifs (si direction = -1, sens anti-horaire)
    if (newIndex < 0) {
      newIndex += playerOrder.length;
    }

    print('🔄 Tour suivant calculé:');
    print('   Liste: ${playerOrder.length} joueurs');
    print('   ${currentIndex} (joueur actuel) → ${newIndex} (suivant)');
    print('   Direction: ${direction == 1 ? "horaire ↻" : "anti-horaire ↺"}');
    if (additionalSkips > 0) {
      print('   ⏭️  Sauts: $additionalSkips joueur(s) sauté(s)');
    }

    return {
      'playerId': playerOrder[newIndex],
      'index': newIndex,
    };
  }

  /// Convertit une PlayingCard en Map pour Firestore
  Map<String, int> _cardToJson(PlayingCard card) {
    return {
      'suit': card.suit.index,
      'value': card.value.index,
    };
  }

  /// Convertit une Map Firestore en PlayingCard
  PlayingCard _jsonToCard(Map<String, dynamic> json) {
    return PlayingCard(
      suit: CardSuit.values[json['suit'] as int],
      value: CardValue.values[json['value'] as int],
    );
  }
}
