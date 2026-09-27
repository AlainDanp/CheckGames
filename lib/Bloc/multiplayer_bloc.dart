import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/card_suit.dart';
import '../models/player_card.dart';
import '../models/playing_card.dart';
import '../models/card_value.dart';
import '../repository/checkgame_repository.dart';
import '../services/game_action_service.dart';
import '../utils/app_logger.dart';
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
    appLogger.d('MultiplayerGameBloc: Initialisation');

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
    appLogger.d('MultiplayerGameBloc: Fermeture');
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
          appLogger.w('Room document introuvable — hôte déconnecté');
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

        // Détecter les changements de tour
        if (_lastCurrentPlayerId != null && _lastCurrentPlayerId != newCurrentPlayerId) {
          final isMyTurn = newCurrentPlayerId == playerId;
          appLogger.d('Changement de tour — mon tour: $isMyTurn');
        } else if (_lastCurrentPlayerId == null) {
          appLogger.d('Premier tour reçu');
        }

        _lastCurrentPlayerId = newCurrentPlayerId;
        _roomData = data;
        _tryEmitState();
      },
      onError: (error) {
        appLogger.e('Erreur listener room', error: error);
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
          appLogger.d('Game state pas encore disponible');
          return;
        }
        _gameStateData = snapshot.data();
        _tryEmitState();
      },
      onError: (error) {
        appLogger.e('Erreur listener game state', error: error);
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
          appLogger.d('Main joueur pas encore disponible');
          return;
        }
        final data = snapshot.data()!;
        _myHand = (data['cards'] as List)
            .map((c) => _jsonToCard(c as Map<String, dynamic>))
            .toList();
        _tryEmitState();
      },
      onError: (error) {
        appLogger.e('Erreur listener player hand', error: error);
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
        _playersData = {};
        for (final doc in snapshot.docs) {
          _playersData![doc.id] = doc.data();
        }
        _tryEmitState();
      },
      onError: (error) {
        appLogger.e('Erreur listener players', error: error);
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
      appLogger.d('En attente de toutes les données Firebase');
      return;
    }

    try {
      // Construire la liste des joueurs
      final playerOrder = List<String>.from(_gameStateData!['playerOrder']);
      final players = <Player>[];

      for (final uid in playerOrder) {
        final playerData = _playersData![uid];
        if (playerData == null) {
          appLogger.w('Données manquantes pour un joueur — skip');
          continue;
        }

        final handSize = playerData['handSize'] as int? ?? 0;
        final isMe = uid == playerId;

        final hand = isMe
            ? _myHand! // Ma main privée
            : List<PlayingCard>.generate(
                handSize,
                (index) => PlayingCard(
                  suit: CardSuit.values[index % CardSuit.values.length],
                  value: CardValue.two,
                ),
              ); // Cartes masquées uniques pour les autres

        players.add(Player(
          id: uid,
          name: playerData['playerName'] as String,
          hand: hand,
        ));
      }

      // Construire la pile de défausse
      final discardPile = (_gameStateData!['discardPile'] as List)
          .map((c) => _jsonToCard(c as Map<String, dynamic>))
          .toList();

      // Trouver l'index du joueur actuel
      final currentPlayerId = _roomData!['currentPlayerId'] as String;
      final currentPlayerIndex = players.indexWhere((p) => p.id == currentPlayerId);

      if (currentPlayerIndex == -1) {
        appLogger.e('currentPlayerId introuvable dans la liste des joueurs');
        return;
      }

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

      appLogger.d('Nouvel état Firebase émis — ${players.length} joueurs');
      emit(newState);
    } catch (e, stackTrace) {
      appLogger.e('Erreur construction état Firebase', error: e, stackTrace: stackTrace);
    }
  }

  // ============================================================================
  // PLAYER ACTIONS (Delegates to GameActionService)
  // ============================================================================

  /// Jouer une carte - Délègue à GameActionService
  Future<void> _onPlayCard(PlayCard event, Emitter<CheckgamesState> emit) async {
    // Vérifier que c'est le tour du joueur
    final isMyTurn = state.isPlayerTurn(playerId);

    if (!isMyTurn) {
      appLogger.w('PlayCard rejeté — pas le tour du joueur');
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

    try {
      // Déléguer l'action au service
      await _actionService.playCard(
        roomId: roomId,
        playerId: playerId,
        cards: event.cards,
        imposedSuit: event.imposedSuit,
      );
      // L'état sera mis à jour automatiquement via les listeners Firebase
    } catch (e) {
      appLogger.e('Erreur playCard', error: e);
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
    if (!state.isPlayerTurn(playerId)) {
      appLogger.w('DrawCard rejeté — pas le tour du joueur');
      return;
    }

    try {
      await _actionService.drawCard(
        roomId: roomId,
        playerId: playerId,
        count: event.count,
      );
      // L'état sera mis à jour automatiquement via les listeners Firebase
    } catch (e) {
      appLogger.e('Erreur drawCard', error: e);
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
    if (!state.isPlayerTurn(playerId)) {
      appLogger.w('EndTurn rejeté — pas le tour du joueur');
      return;
    }

    try {
      await _actionService.endTurn(
        roomId: roomId,
        playerId: playerId,
      );
      // L'état sera mis à jour automatiquement via les listeners Firebase
    } catch (e) {
      appLogger.e('Erreur endTurn', error: e);
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
