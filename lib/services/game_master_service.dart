import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/playing_card.dart';
import '../models/card_suit.dart';
import '../models/card_value.dart';
import '../logic/deckgenerator.dart';
import '../utils/app_logger.dart';

/// Service responsable de l'initialisation et de la gestion serveur du jeu
/// Ce service est la SEULE source qui peut créer et initialiser l'état du jeu
class GameMasterService {
  final FirebaseFirestore _firestore;

  GameMasterService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialise une nouvelle partie multijoueur
  /// Cette méthode utilise une transaction atomique pour garantir la cohérence
  ///
  /// IMPORTANT: Cette méthode doit être appelée UNE SEULE FOIS par l'hôte
  Future<void> initializeGame(String roomId) async {
    appLogger.d('GameMasterService: Début initialisation partie');

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Générer et mélanger le deck
        final deck = DeckGenerator.shuffledDeck(includeJokers: true);
        appLogger.d('Deck généré: ${deck.length} cartes');

        // 2. Récupérer les joueurs de la room (par ordre de position)
        final playersSnapshot = await _firestore
            .collection('game_rooms')
            .doc(roomId)
            .collection('players')
            .orderBy('position')
            .get();

        if (playersSnapshot.docs.isEmpty) {
          throw Exception('Aucun joueur trouvé dans la room');
        }

        // Créer la liste de tour (playerOrder) : [hôte, joueur2, joueur3, ...]
        final playerUids = playersSnapshot.docs.map((doc) => doc.id).toList();
        appLogger.d('Ordre de jeu établi: ${playerUids.length} joueurs');

        // 3. Distribuer 5 cartes à chaque joueur
        final hands = <String, List<Map<String, int>>>{};
        int cardIndex = 0;

        for (var uid in playerUids) {
          final playerHand = <Map<String, int>>[];
          for (int i = 0; i < 5; i++) {
            if (cardIndex >= deck.length) {
              throw Exception('Pas assez de cartes dans le deck');
            }
            playerHand.add(_cardToJson(deck[cardIndex]));
            cardIndex++;
          }
          hands[uid] = playerHand;
        }

        // 4. Trouver la première carte non-spéciale pour la défausse
        final firstCard = _drawNonSpecialCard(deck, startIndex: cardIndex);
        final discardPile = [_cardToJson(firstCard.card)];
        cardIndex = firstCard.newIndex;

        // 5. Le reste du deck devient la pioche
        final remainingDeck = deck.sublist(cardIndex);
        appLogger.d('Cartes restantes dans la pioche: ${remainingDeck.length}');

        // 6. Mettre à jour le document principal de la room
        transaction.update(
          _firestore.collection('game_rooms').doc(roomId),
          {
            'status': 'playing',
            'currentPlayerId': playerUids[0],
            'direction': 1, // 1 = sens horaire, -1 = anti-horaire
            'skipCount': 0,
            'cardsToDraw': 0,
            'imposedSuit': null,
            'phase': 'normal', // normal | duel | cumulus
            'isGameOver': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // 7. Créer le document game_state/current
        transaction.set(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('current'),
          {
            'deckSize': remainingDeck.length,
            'discardPile': discardPile,
            'playerOrder': playerUids,
            'finishingOrder': [], // UIDs des joueurs qui ont terminé
            'lastAction': {
              'playerId': 'system',
              'type': 'init_game',
              'timestamp': FieldValue.serverTimestamp(),
            },
          },
        );

        // 8. Sauvegarder les mains privées de chaque joueur
        for (var entry in hands.entries) {
          transaction.set(
            _firestore
                .collection('game_rooms')
                .doc(roomId)
                .collection('player_hands')
                .doc(entry.key),
            {'cards': entry.value},
          );

          // Mettre à jour le handSize public du joueur
          transaction.set(
            _firestore
                .collection('game_rooms')
                .doc(roomId)
                .collection('players')
                .doc(entry.key),
            {'handSize': entry.value.length},
            SetOptions(merge: true),
          );
        }

        // 9. Sauvegarder le deck restant (privé, utilisé côté serveur)
        transaction.set(
          _firestore.collection('game_rooms').doc(roomId).collection('game_state').doc('deck'),
          {
            'cards': remainingDeck.map(_cardToJson).toList(),
          },
        );

        // 10. Logger l'action d'initialisation
        transaction.set(
          _firestore.collection('game_rooms').doc(roomId).collection('actions').doc(),
          {
            'playerId': 'system',
            'type': 'init_game',
            'data': {
              'playerCount': playerUids.length,
              'initialDeckSize': deck.length,
              'remainingDeckSize': remainingDeck.length,
            },
            'timestamp': FieldValue.serverTimestamp(),
          },
        );
      });

      appLogger.i('GameMasterService: Partie initialisée avec succès');
    } catch (e) {
      appLogger.e('GameMasterService: Erreur initialisation', error: e);
      rethrow;
    }
  }

  /// Relance une partie existante
  /// IMPORTANT: Cette méthode doit être appelée UNIQUEMENT par l'hôte
  Future<void> restartGame(String roomId) async {
    appLogger.d('GameMasterService: Relance de partie');

    try {
      // Vérifier que la room existe
      final roomDoc = await _firestore.collection('game_rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room introuvable');
      }

      // Réutiliser la logique d'initialisation
      await initializeGame(roomId);

      appLogger.i('GameMasterService: Partie relancée avec succès');
    } catch (e) {
      appLogger.e('GameMasterService: Erreur relance', error: e);
      rethrow;
    }
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

  /// Tire la première carte non-spéciale du deck
  ({PlayingCard card, int newIndex}) _drawNonSpecialCard(
    List<PlayingCard> deck, {
    required int startIndex,
  }) {
    for (int i = startIndex; i < deck.length; i++) {
      final card = deck[i];
      if (![
        CardValue.ace,
        CardValue.seven,
        CardValue.joker,
        CardValue.jack,
        CardValue.two,
      ].contains(card.value)) {
        return (card: card, newIndex: i + 1);
      }
    }

    if (startIndex < deck.length) {
      return (card: deck[startIndex], newIndex: startIndex + 1);
    }

    throw Exception('Plus de cartes disponibles dans le deck');
  }
}
