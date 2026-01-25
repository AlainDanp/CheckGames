import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/card_suit.dart';
import '../models/player_card.dart';
import '../models/playing_card.dart';
import '../models/card_value.dart';
import '../repository/checkgame_repository.dart';
import '../services/game_action_service.dart';
import 'checkgames_event.dart';
import 'checkgames_state.dart';

/// MultiplayerGameBloc refactoré: Pure listener pattern
///
/// Ce Bloc ne génère AUCUN état localement.
/// Il ne fait qu'écouter Firebase et émettre les états reçus.
/// Toutes les actions (play, draw, end turn) sont déléguées à GameActionService.
class MultiplayerGameBloc extends Bloc<CheckgamesEvent, CheckgamesState> {
  final String roomId;
  final String playerId;
  final CheckgameRepository repository;
  final GameActionService _actionService;
  final FirebaseFirestore _firestore;

  // Subscriptions multiples pour écouter toutes les sources
  StreamSubscription? _roomSubscription;
  StreamSubscription? _gameStateSubscription;
  StreamSubscription? _handSubscription;
  StreamSubscription? _playersSubscription;

  // État temporaire pour construire le CheckgamesState
  Map<String, dynamic>? _roomData;
  Map<String, dynamic>? _gameStateData;
  List<PlayingCard>? _myHand;
  Map<String, Map<String, dynamic>>? _playersData;

  MultiplayerGameBloc({
    required this.roomId,
    required this.playerId,
    required this.repository,
    GameActionService? actionService,
    FirebaseFirestore? firestore,
  })  : _actionService = actionService ?? GameActionService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        super(const CheckgamesState()) {
    print('🎮 MultiplayerGameBloc: Initialisation pour room $roomId, joueur $playerId');

    // Ajouter les handlers pour les actions du joueur
    on<PlayCard>(_onPlayCard);
    on<DrawCard>(_onDrawCard);
    on<EndTurn>(_onEndTurn);

    // Ignorer les événements solo-player en mode multiplayer
    on<StartGame>(_onIgnoreEvent);
    on<RestartGame>(_onIgnoreEvent);
    on<BotActionRequested>(_onIgnoreEvent);
    on<SetPaused>(_onIgnoreEvent);

    // Démarrer les listeners
    _listenToRoom();
    _listenToGameState();
    _listenToPlayerHand();
    _listenToPlayers();
  }

  @override
  Future<void> close() {
    print('🎮 MultiplayerGameBloc: Fermeture et annulation des listeners');
    _roomSubscription?.cancel();
    _gameStateSubscription?.cancel();
    _handSubscription?.cancel();
    _playersSubscription?.cancel();
    return super.close();
  }

  // ============================================================================
  // FIREBASE LISTENERS (Read-Only)
  // ============================================================================

  // Variable pour détecter les changements de tour
  String? _lastCurrentPlayerId;

  /// Écoute le document principal de la room
  void _listenToRoom() {
    _roomSubscription = _firestore
        .collection('game_rooms')
        .doc(roomId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          print('⚠️ Room document n\'existe pas - Host probablement déconnecté');
          // Émettre un état d'erreur pour indiquer que la partie est terminée
          emit(state.copyWith(
            errorMessage: '🚫 La partie a été fermée par l\'hôte',
            isGameOver: true,
            phase: GamePhase.finished,
          ));
          return;
        }
        final data = snapshot.data()!;
        final newCurrentPlayerId = data['currentPlayerId'] as String;

        print('🔥 ========================================');
        print('🔥 FIREBASE UPDATE: Room data reçue');
        print('🔥 currentPlayerId: $newCurrentPlayerId');
        print('🔥 status: ${data['status']}');

        // Détecter les changements de tour
        if (_lastCurrentPlayerId != null && _lastCurrentPlayerId != newCurrentPlayerId) {
          print('🔄 🔔 CHANGEMENT DE TOUR DÉTECTÉ !');
          print('   Ancien joueur: $_lastCurrentPlayerId');
          print('   Nouveau joueur: $newCurrentPlayerId');
          print('   C\'est moi ? ${newCurrentPlayerId == playerId ? "OUI ✅" : "NON ❌"}');
        } else if (_lastCurrentPlayerId == null) {
          print('🔄 Premier tour: $newCurrentPlayerId');
          print('   C\'est moi ? ${newCurrentPlayerId == playerId ? "OUI ✅" : "NON ❌"}');
        }

        _lastCurrentPlayerId = newCurrentPlayerId;
        print('🔥 ========================================');

        _roomData = data;
        _tryEmitState();
      },
      onError: (error) {
        print('❌ Erreur listener room: $error');
      },
    );
  }

  /// Écoute l'état public du jeu (game_state/current)
  void _listenToGameState() {
    _gameStateSubscription = _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('game_state')
        .doc('current')
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          print('⚠️ Game state n\'existe pas encore');
          return;
        }
        print('🔥 Game state reçu');
        _gameStateData = snapshot.data();
        _tryEmitState();
      },
      onError: (error) {
        print('❌ Erreur listener game state: $error');
      },
    );
  }

  /// Écoute la main privée du joueur
  void _listenToPlayerHand() {
    _handSubscription = _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('player_hands')
        .doc(playerId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          print('⚠️ Player hand n\'existe pas encore');
          return;
        }
        print('🔥 Player hand reçue');
        final data = snapshot.data()!;
        _myHand = (data['cards'] as List)
            .map((c) => _jsonToCard(c as Map<String, dynamic>))
            .toList();
        _tryEmitState();
      },
      onError: (error) {
        print('❌ Erreur listener player hand: $error');
      },
    );
  }

  /// Écoute les métadonnées publiques des joueurs
  void _listenToPlayers() {
    _playersSubscription = _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('players')
        .orderBy('position')
        .snapshots()
        .listen(
      (snapshot) {
        print('🔥 Players data reçue: ${snapshot.docs.length} joueurs');
        _playersData = {};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          print('🔥   - Joueur ${doc.id}: handSize=${data['handSize']}, name=${data['playerName']}');
          _playersData![doc.id] = data;
        }
        _tryEmitState();
      },
      onError: (error) {
        print('❌ Erreur listener players: $error');
      },
    );
  }

  /// Essaye de construire et émettre un état complet
  /// N'émet que si toutes les données sont disponibles
  void _tryEmitState() {
    if (_roomData == null ||
        _gameStateData == null ||
        _myHand == null ||
        _playersData == null) {
      print('⏳ En attente de toutes les données Firebase...');
      print('  - roomData: ${_roomData != null ? "✅" : "❌"}');
      print('  - gameStateData: ${_gameStateData != null ? "✅" : "❌"}');
      print('  - myHand: ${_myHand != null ? "✅" : "❌"}');
      print('  - playersData: ${_playersData != null ? "✅" : "❌"}');
      return;
    }

    try {
      print('🔄 Construction de l\'état depuis Firebase...');

      // Construire la liste des joueurs
      final playerOrder = List<String>.from(_gameStateData!['playerOrder']);
      print('📋 PlayerOrder Firebase: $playerOrder');

      final players = <Player>[];

      for (final uid in playerOrder) {
        final playerData = _playersData![uid];
        if (playerData == null) {
          print('⚠️ CRITIQUE: Données manquantes pour le joueur $uid - SKIP (peut causer bug d\'index)');
          continue;
        }

        final handSize = playerData['handSize'] as int? ?? 0;
        final isMe = uid == playerId;

        print('🎴 Joueur $uid (${isMe ? "MOI" : "AUTRE"}): handSize=$handSize, myHandLength=${isMe ? _myHand!.length : "N/A"}');

        final hand = isMe
            ? _myHand! // Ma main privée
            : List<PlayingCard>.generate(
                handSize,
                (index) => PlayingCard(
                  suit: CardSuit.values[index % CardSuit.values.length],
                  value: CardValue.two,
                ),
              ); // Cartes masquées uniques pour les autres

        print('🎴 Main créée pour $uid: ${hand.length} cartes');

        players.add(Player(
          id: uid,
          name: playerData['playerName'] as String,
          hand: hand,
        ));
      }

      print('👥 Liste players construite: ${players.length} joueurs');
      for (int i = 0; i < players.length; i++) {
        print('   [$i] ${players[i].name} (${players[i].id})');
      }

      // Construire la pile de défausse
      final discardPile = (_gameStateData!['discardPile'] as List)
          .map((c) => _jsonToCard(c as Map<String, dynamic>))
          .toList();

      // Trouver l'index du joueur actuel
      final currentPlayerId = _roomData!['currentPlayerId'] as String;
      print('🎯 CurrentPlayerId Firebase: $currentPlayerId');

      // BUGFIX: Trouver l'index dans la liste players construite, pas dans playerOrder
      final currentPlayerIndex = players.indexWhere((p) => p.id == currentPlayerId);

      print('🎯 CurrentPlayerIndex calculé: $currentPlayerIndex');
      if (currentPlayerIndex == -1) {
        print('❌ ERREUR: currentPlayerId $currentPlayerId introuvable dans players !');
        return;
      }

      print('🎯 Joueur actuel: ${players[currentPlayerIndex].name} (${currentPlayerId == playerId ? "C\'EST MOI ✅" : "PAS MOI ❌"})');

      // Créer un drawPile factice avec le bon nombre de cartes uniques
      final deckSize = _gameStateData!['deckSize'] as int? ?? 0;
      final drawPile = List<PlayingCard>.generate(
        deckSize,
        (index) => PlayingCard(
          suit: CardSuit.values[index % CardSuit.values.length],
          value: CardValue.values[(index ~/ CardSuit.values.length) % CardValue.values.length],
        ),
      );

      // Construire l'état
      final newState = CheckgamesState(
        players: players,
        currentPlayerIndex: currentPlayerIndex,
        drawPile: drawPile,
        discardPile: discardPile,
        isGameOver: _roomData!['isGameOver'] as bool? ?? false,
        skipCount: _roomData!['skipCount'] as int? ?? 0,
        cardsToDraw: _roomData!['cardsToDraw'] as int? ?? 0,
        imposedSuit: _roomData!['imposedSuit'] != null
            ? CardSuit.values[_roomData!['imposedSuit'] as int]
            : null,
        phase: _parseGamePhase(_roomData!['phase'] as String? ?? 'normal'),
        finishingOrder:
            List<String>.from(_gameStateData!['finishingOrder'] ?? []),
        shouldWaitForResponse: false,
        isPaused: false,
      );

      print('✅ Nouvel état construit: ${players.length} joueurs, currentPlayerIndex: $currentPlayerIndex');
      print('✅   currentPlayerId: $currentPlayerId (${currentPlayerId == playerId ? "MOI" : "AUTRE"})');
      print('✅ ÉMISSION DU NOUVEL ÉTAT');
      print('   → Les widgets vont se mettre à jour');
      print('   → isPlayerTurn($playerId) sera maintenant: ${newState.isPlayerTurn(playerId)}');
      print('🔄 ========================================');
      emit(newState);
    } catch (e, stackTrace) {
      print('❌ Erreur lors de la construction de l\'état: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // ============================================================================
  // PLAYER ACTIONS (Delegates to GameActionService)
  // ============================================================================

  /// Jouer une carte - Délègue à GameActionService
  Future<void> _onPlayCard(PlayCard event, Emitter<CheckgamesState> emit) async {
    print('🎮 ========================================');
    print('🎮 MultiplayerGameBloc.playCard APPELÉ');
    print('🎮 Joueur: $playerId');
    print('🎮 Cartes à jouer: ${event.cards.length}');
    print('🎮 État actuel:');
    print('   - currentPlayerIndex: ${state.currentPlayerIndex}');
    print('   - currentPlayer: ${state.currentPlayer?.name} (${state.currentPlayer?.id})');
    print('   - players.length: ${state.players.length}');

    // Vérifier que c'est le tour du joueur
    final isMyTurn = state.isPlayerTurn(playerId);
    print('🎮 isPlayerTurn($playerId) = $isMyTurn');

    if (!isMyTurn) {
      print('❌ REJETÉ: Ce n\'est pas votre tour !');
      print('   Joueur actuel: ${state.currentPlayer?.id}');
      print('   Votre ID: $playerId');
      print('🎮 ========================================');
      emit(state.copyWith(
        errorMessage: 'Ce n\'est pas votre tour !',
      ));
      // Réinitialiser le message d'erreur après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) {
          emit(state.copyWith(errorMessage: null));
        }
      });
      return;
    }

    print('✅ Vérification OK - C\'est votre tour');
    print('🎮 Appel à GameActionService...');

    try {
      // Déléguer l'action au service
      await _actionService.playCard(
        roomId: roomId,
        playerId: playerId,
        cards: event.cards,
        imposedSuit: event.imposedSuit,
      );
      print('✅ GameActionService a réussi - Carte(s) jouée(s)');
      print('🎮 ========================================');
      // L'état sera mis à jour automatiquement via les listeners Firebase
    } catch (e) {
      print('❌ GameActionService a échoué: $e');
      print('🎮 ========================================');
      emit(state.copyWith(
        errorMessage: e.toString(),
      ));
      // Réinitialiser le message d'erreur après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) {
          emit(state.copyWith(errorMessage: null));
        }
      });
    }
  }

  /// Piocher des cartes - Délègue à GameActionService
  Future<void> _onDrawCard(DrawCard event, Emitter<CheckgamesState> emit) async {
    print('🎮 ========================================');
    print('🎮 MultiplayerGameBloc.drawCard APPELÉ');
    print('🎮 Joueur: $playerId');
    print('🎮 Nombre de cartes: ${event.count}');

    if (!state.isPlayerTurn(playerId)) {
      print('❌ REJETÉ: Ce n\'est pas votre tour');
      print('🎮 ========================================');
      return;
    }

    print('✅ Vérification OK - C\'est votre tour');
    print('🎮 Appel à GameActionService...');

    try {
      await _actionService.drawCard(
        roomId: roomId,
        playerId: playerId,
        count: event.count,
      );
      print('✅ GameActionService a réussi - Carte(s) piochée(s)');
      print('🎮 ========================================');
      // L'état sera mis à jour automatiquement via les listeners Firebase
    } catch (e) {
      print('❌ GameActionService a échoué: $e');
      print('🎮 ========================================');
      emit(state.copyWith(
        errorMessage: e.toString(),
      ));
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) {
          emit(state.copyWith(errorMessage: null));
        }
      });
    }
  }

  /// Terminer le tour - Délègue à GameActionService
  Future<void> _onEndTurn(EndTurn event, Emitter<CheckgamesState> emit) async {
    print('🎮 MultiplayerGameBloc: Tentative de terminer le tour');

    if (!state.isPlayerTurn(playerId)) {
      print('⚠️ Ce n\'est pas votre tour');
      return;
    }

    try {
      await _actionService.endTurn(
        roomId: roomId,
        playerId: playerId,
      );
      print('✅ Tour terminé avec succès');
      // L'état sera mis à jour automatiquement via les listeners Firebase
    } catch (e) {
      print('❌ Erreur lors de la fin du tour: $e');
      emit(state.copyWith(
        errorMessage: e.toString(),
      ));
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) {
          emit(state.copyWith(errorMessage: null));
        }
      });
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Ignore les événements qui ne sont pas pertinents en mode multiplayer
  void _onIgnoreEvent(CheckgamesEvent event, Emitter<CheckgamesState> emit) {
    print('🎮 MultiplayerGameBloc: Événement ${event.runtimeType} ignoré en mode multiplayer');
    // Ne rien faire - ces événements sont pour le mode solo uniquement
  }

  /// Convertit une Map Firestore en PlayingCard
  PlayingCard _jsonToCard(Map<String, dynamic> json) {
    return PlayingCard(
      suit: CardSuit.values[json['suit'] as int],
      value: CardValue.values[json['value'] as int],
    );
  }

  /// Parse le GamePhase depuis une string
  GamePhase _parseGamePhase(String phase) {
    switch (phase) {
      case 'duel':
        return GamePhase.duel;
      case 'finished':
        return GamePhase.finished;
      default:
        return GamePhase.normal;
    }
  }
}
