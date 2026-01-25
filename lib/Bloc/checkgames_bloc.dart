import '../models/card_suit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/player_card.dart';
import '../models/playing_card.dart';
import '../logic/deckgenerator.dart';
import '../logic/rule_engine.dart';
import '../models/card_value.dart';
import '../repository/checkgame_repository.dart';
import '../models/game_history.dart';
import '../services/bot_strategy_service.dart';
import '../services/game_settings_service.dart';

import 'checkgames_event.dart';
import 'checkgames_state.dart';

class CheckGameBloc extends Bloc<CheckgamesEvent, CheckgamesState>{
    final CheckgameRepository repository;

    CheckGameBloc({required this.repository}) : super(const CheckgamesState()){
      on<StartGame>(_onStartGame);
      on<PlayCard>(_onPlayCard);
      on<DrawCard>(_onDrawCard);
      on<EndTurn>(_onEndTurn);
      on<RestartGame>(_onRestartGame);
      on<BotActionRequested>(_onBotAction);
      on<SetPaused>(_onSetPaused);
    }

    ///Démarrage du jeu;
    void _onStartGame(StartGame event, Emitter<CheckgamesState> emit){
      final deck = DeckGenerator.generateFullDeck()..shuffle();

      final players = <Player>[];
      for (var i = 0; i < event.playerNames.length; i++){
        final name = event.playerNames[i];
        final hand = deck.take(5).toList();
        deck.removeRange(0, 5);
        players.add(Player(id: '$i', name: name, hand: hand));
      }

      final first = _drawFirstNonSpecial(deck); // ci-dessous
      final discard = [first];

      final draw = List<PlayingCard>.from(deck);

      emit(CheckgamesState(
        players: players,
        drawPile: draw,
        discardPile: discard,
        currentPlayerIndex: 0,
        skipCount: 0,
        cardsToDraw: 0,
        imposedSuit: null,
        isGameOver: false,
        phase: GamePhase.normal,
        finishingOrder: const [],
      ));

      _maybeTriggerBot();

    }

    /// Jouer une carte si autorisé
    void _onPlayCard(PlayCard event, Emitter<CheckgamesState> emit) {
      if (state.players.isEmpty) return;

      // Validation sécurisée de l'index
      final currentPlayer = _getCurrentPlayer();
      if (currentPlayer == null) return;
      if (currentPlayer.id != event.playerId) return;
      if (event.cards.isEmpty) return;
      final cards = event.cards;

      // toutes appartiennent ?
      if (!cards.every((c) => currentPlayer.hand.contains(c))) return;
      // double-coup: même valeur
      if (!cards.every((c) => c.value == cards.first.value)) return;

      final top = state.discardPile.last;

      // ── 1) CUMULUS : n'accepter que 7/Joker, sans vérifier couleur/valeur
      if (state.cardsToDraw > 0) {
        final allCounter = cards.every((c) =>
        c.value == CardValue.seven || c.value == CardValue.joker);
        if (!allCounter) return;

        // mise à jour main
        final newHand = [...currentPlayer.hand]..removeWhere(cards.contains);
        final players = state.players.map((p) =>
        p.id == currentPlayer.id ? p.copyWith(hand: newHand) : p
        ).toList();

        // défausse
        final discard = [...state.discardPile, ...cards];

        // Détecter si le joueur n'a plus qu'1 carte → "CHECKS!"
        String? checksPlayerId;
        if (newHand.length == 1) {
          checksPlayerId = currentPlayer.id;
        }

        // cumul
        int draw = state.cardsToDraw;
        for (final c in cards) {
          if (c.value == CardValue.seven) draw += 2;
          if (c.value == CardValue.joker) draw += 4;
        }

        final nextIndex = (state.currentPlayerIndex + 1) % state.players.length;

        emit(state.copyWith(
          players: players,
          discardPile: discard,
          currentPlayerIndex: nextIndex,
          cardsToDraw: draw,
          // imposition inchangée (si existait)
          skipCount: 0,
          lastChecksPlayerId: checksPlayerId,
        ));

        _maybeTriggerBot();
        return;
      }

      // ── 2) CAS NORMAL
      final first = cards.first;

      if(first.value == CardValue.jack && event.imposedSuit == null) return;

      final canPlay = RuleEngine.canPlayCard(
        cardToPlay: first,
        topCard: top,
        imposedSuit: state.imposedSuit,
        pendingDraw: state.cardsToDraw,
      );

      if (!canPlay) {
        // Émettre un message d'erreur pour manœuvre invalide UNIQUEMENT pour le joueur humain (id = '0')
        // ET uniquement pour les cartes normales (pas les cartes spéciales comme 2, J, 7, Joker, As)
        if (event.playerId == '0') {
          // Ne pas afficher le message pour les cartes spéciales
          final isSpecialCard = first.value == CardValue.two ||
                                 first.value == CardValue.jack ||
                                 first.value == CardValue.seven ||
                                 first.value == CardValue.joker ||
                                 first.value == CardValue.ace;

          if (!isSpecialCard) {
            emit(state.copyWith(
              errorMessage: 'Manœuvre impossible ! Cette carte ne peut pas être jouée ici.',
            ));
            // Réinitialiser le message après un court délai
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!isClosed) {
                emit(state.copyWith(errorMessage: null));
              }
            });
          }
        }
        return;
      }


      // mise à jour main
      final newHand = [...currentPlayer.hand]..removeWhere(cards.contains);
      final players = state.players.map((p) =>
      p.id == currentPlayer.id ? p.copyWith(hand: newHand) : p
      ).toList();

      // défausse
      final discard = [...state.discardPile, ...cards];

      // Détecter si le joueur n'a plus qu'1 carte → "CHECKS!"
      final checksPlayerId = newHand.length == 1 ? currentPlayer.id : null;

      int skip = 0;
      int draw = 0;
      CardSuit? imposed = state.imposedSuit;


      for (final c in cards) {
        switch (c.value) {
          case CardValue.ace:
            skip += 1;
            break;
          case CardValue.seven:
            draw += 2;
            break;
          case CardValue.joker:
            draw += 4;
            break;
          case CardValue.jack:
            if (event.imposedSuit == null) return; // J doit imposer
            imposed = event.imposedSuit;           // impose la nouvelle couleur
            break;
          default:
            break;
        }
      }

      // Consommer l'imposition si elle a été respectée
      if (state.imposedSuit != null && first.value != CardValue.jack) {
        // Cas 1: Carte normale qui matche la couleur imposée
        if (first.suit == state.imposedSuit) {
          imposed = null;
        }
        // Cas 2: Deux (wildcard) - consomme toujours l'imposition
        else if (first.value == CardValue.two) {
          imposed = null;
        }
        // Cas 3: Joker de la bonne couleur
        else if (first.value == CardValue.joker) {
          final isRedImposed = state.imposedSuit == CardSuit.hearts ||
                               state.imposedSuit == CardSuit.diamonds;
          final isRedJoker = first.suit == CardSuit.jokerRed;
          if ((isRedImposed && isRedJoker) || (!isRedImposed && !isRedJoker)) {
            imposed = null;
          }
        }
      }

      // Calculer le prochain joueur en sautant si un As a été joué
      final nextIndex = (state.currentPlayerIndex + 1 + skip) % state.players.length;

      // Cas spécial : fin du duel
      if (state.phase == GamePhase.duel && newHand.isEmpty) {
        List<String> order = List.of(state.finishingOrder);
        order.add(currentPlayer.id);

        // L'autre joueur du duel finit automatiquement 2e
        final activePlayers = _activePlayers(players, order);
        if (activePlayers.length == 1) {
          order.add(activePlayers.first.id);
        }

        // Sauvegarder l'historique et les stats
        final playerNames = state.players.map((p) => p.name).toList();
        repository.saveGameHistory(GameHistory(
          date: DateTime.now(),
          playerNames: playerNames,
          finishingOrder: order,
          hadDuel: true,
        ));

        // Sauvegarder les stats de chaque joueur
        for (int i = 0; i < order.length; i++) {
          final playerId = order[i];
          final player = players.firstWhere((p) => p.id == playerId);
          final position = i + 1;

          repository.recordGameResult(
            playerName: player.name,
            position: position,
          );
        }

        emit(state.copyWith(
          players: players,
          discardPile: discard,
          currentPlayerIndex: state.currentPlayerIndex,
          skipCount: 0,
          cardsToDraw: draw,
          imposedSuit: imposed,
          isGameOver: true,
          finishingOrder: order,
          phase: GamePhase.finished,
        ));
        return;
      }

      // victoire si main vide
      List<String> order = List.of(state.finishingOrder);
      GamePhase nextPhase = state.phase;
      bool gameOver = false;

      if (newHand.isEmpty) {
        order.add(currentPlayer.id);

        // Joueurs encore actifs
        final activePlayers = _activePlayers(players, order);

        if (activePlayers.length == 1) {
          // Dernier joueur → partie terminée
          order.add(activePlayers.first.id);
          gameOver = true;
          nextPhase = GamePhase.finished;

          // Sauvegarder l'historique et les stats
          final playerNames = state.players.map((p) => p.name).toList();
          repository.saveGameHistory(GameHistory(
            date: DateTime.now(),
            playerNames: playerNames,
            finishingOrder: order,
            hadDuel: false,
          ));

          // Sauvegarder les stats de chaque joueur
          for (int i = 0; i < order.length; i++) {
            final playerId = order[i];
            final player = players.firstWhere((p) => p.id == playerId);
            final position = i + 1;

            repository.recordGameResult(
              playerName: player.name,
              position: position,
            );
          }
        } else if (activePlayers.length == 2 && state.phase != GamePhase.duel) {
          // Déclencher le duel
          nextPhase = GamePhase.duel;
        }
      }

      emit(state.copyWith(
        players: players,
        discardPile: discard,
        currentPlayerIndex: gameOver ? state.currentPlayerIndex : nextIndex,
        skipCount: 0,
        cardsToDraw: draw,
        imposedSuit: imposed,
        isGameOver: gameOver,
        finishingOrder: order,
        phase: nextPhase,
        lastChecksPlayerId: checksPlayerId,
      ));

      // Appeler _startDuel après emit si nécessaire
      if (nextPhase == GamePhase.duel && state.phase != GamePhase.duel) {
        final activePlayers = _activePlayers(players, order);
        _startDuel(emit, activePlayers);
      }

      if (!gameOver) _maybeTriggerBot();
    }

    /// piocher des cartes
    void _onDrawCard(DrawCard event, Emitter<CheckgamesState> emit) {
      // Validation sécurisée de l'index
      final currentPlayer = _getCurrentPlayer();
      if (currentPlayer == null) return;

      // Vérifier que c'est bien le joueur qui demande à piocher
      if (currentPlayer.id != event.playerId) return; // pas son tour

      // si cumulus actif, ignorer DrawCard manuel (la pioche se fait dans EndTurn)
      if (state.cardsToDraw > 0) return;

      final count = event.count;
      final drawPile = List<PlayingCard>.from(state.drawPile);
      final drawn = <PlayingCard>[];

      // Recycler la défausse si la pioche est vide
      var discard = List<PlayingCard>.from(state.discardPile);
      if (drawPile.isEmpty && discard.length > 1) {
        final top = discard.removeLast();
        drawPile.addAll(discard..shuffle());
        discard = [top];
      }

      // Piocher autant de cartes que possible (peut être moins si pas assez)
      for (int i = 0; i < count && drawPile.isNotEmpty; i++) {
        drawn.add(drawPile.removeAt(0));
      }

      final players = state.players.map((p) {
        if (p.id == currentPlayer.id) {
          return p.copyWith(hand: [...p.hand, ...drawn]);
        }
        return p;
      }).toList();

      final nextIndex = (state.currentPlayerIndex + 1) % state.players.length;

      emit(state.copyWith(
        players: players,
        drawPile: drawPile,
        discardPile: discard,
        // Fin immédiate du tour
        currentPlayerIndex: nextIndex,
        // aucune modif d’imposition/cumul ici
      ));

      _maybeTriggerBot();
    }

    /// Passer au joueur suivant
    void _onEndTurn(EndTurn event, Emitter<CheckgamesState> emit) {
      final n = state.players.length;
      if (n == 0) return;

      final currentIndex = state.currentPlayerIndex;
      // Validation sécurisée de l'index
      if (currentIndex < 0 || currentIndex >= n) return;
      final currentPlayer = state.players[currentIndex];

      var drawPile = List<PlayingCard>.from(state.drawPile);
      var discard  = List<PlayingCard>.from(state.discardPile);

      // Recycler la défausse si la pioche est vide
      if (drawPile.isEmpty && discard.length > 1) {
        final top = discard.removeLast();
        drawPile = List.of(discard)..shuffle();
        discard = [top];
      }

      //  Cas effet cumulé (7/joker) : la pioche s'applique au JOUEUR COURANT
      if (state.cardsToDraw > 0) {
        final drawn = <PlayingCard>[];
        // Piocher autant de cartes que possible (peut être moins si pas assez)
        for (int i = 0; i < state.cardsToDraw && drawPile.isNotEmpty; i++) {
          drawn.add(drawPile.removeAt(0));
        }
        final players = state.players.map((p) =>
        p.id == currentPlayer.id ? p.copyWith(hand: [...p.hand, ...drawn]) : p
        ).toList();

        emit(state.copyWith(
          players: players,
          drawPile: drawPile,
          discardPile: discard,
          cardsToDraw: 0,
          currentPlayerIndex: (currentIndex + 1) % n, // avance après pioche
        ));
        _maybeTriggerBot();
        return; //  pas de "carte bonus" dans ce cas
      }

      //  Cas normal (pas d’effet en attente) : on regarde si le prochain peut jouer, sinon il pioche 1
      final nextIndex = (currentIndex + 1) % n;
      final nextPlayer = state.players[nextIndex];


      bool hasImposed = true;
      if (state.imposedSuit != null) {
        hasImposed = nextPlayer.hand.any((c) {
          if (c.value == CardValue.two) return true;
          if (c.value == CardValue.joker) {
            final imposed = state.imposedSuit!;
            final isRed = (imposed == CardSuit.hearts || imposed == CardSuit.diamonds);
            return isRed ? c.suit == CardSuit.jokerRed : c.suit == CardSuit.jokerBlack;
          }
          return c.suit == state.imposedSuit;
        });
      }

      if (state.imposedSuit != null && !hasImposed) {
        PlayingCard? extra;
        if (drawPile.isNotEmpty) extra = drawPile.removeAt(0);
        final players = state.players.map((p) {
          if (p.id == nextPlayer.id && extra != null) {
            return p.copyWith(hand: [...p.hand, extra]);
          }
          return p;
        }).toList();

        emit(state.copyWith(
          players: players,
          drawPile: drawPile,
          discardPile: discard,
          currentPlayerIndex: (nextIndex + 1) % n, // fin du tour
        ));
        _maybeTriggerBot();
        return;
      }

      // Peut-il jouer ?
      final canPlay = RuleEngine.playerHasPlayableCard(
        hand: nextPlayer.hand,
        topCard: discard.last,
        imposedSuit: state.imposedSuit,
      );

      PlayingCard? extraCard;
      if (!canPlay && drawPile.isNotEmpty) {
        extraCard = drawPile.removeAt(0);
      }


      final updatedPlayers = state.players.map((p) {
        if (p.id == nextPlayer.id && extraCard != null) {
          return p.copyWith(hand: [...p.hand, extraCard]);
        }
        return p;
      }).toList();

      // Passe le tour APRÈS la pioche forcée
      final newIndex = (!canPlay) ? (nextIndex + 1) % n : nextIndex;

      emit(state.copyWith(
        players: updatedPlayers,
        drawPile: drawPile,
        discardPile: discard,
        currentPlayerIndex: newIndex,
      ));
      _maybeTriggerBot();
    }


    /// Réinitialiser complètement la partie
    void _onRestartGame(RestartGame event, Emitter<CheckgamesState> emit) {
      final oldPlayers = state.players;
      final players = event.keepPlayers ? oldPlayers : [];

      if (players.isEmpty) {
        emit(const CheckgamesState());
        return;
      }

      final deck = DeckGenerator.generateFullDeck()..shuffle();

      final updatedPlayers = players.map<Player>((p)  {
        final hand = deck.take(5).toList();
        deck.removeRange(0, 5); // la main d'un joeur
        return p.copyWith(hand: hand);
      }).toList();

      final first = _drawFirstNonSpecial(deck);
      final discardPile = [first];

      emit(CheckgamesState(
        players: updatedPlayers,
        drawPile: deck,
        discardPile: discardPile,
        currentPlayerIndex: 0,
        skipCount: 0,
        imposedSuit: null,
        isGameOver: false,
        phase: GamePhase.normal,
        finishingOrder: const [],
      ));
      _maybeTriggerBot();
    }

    void _maybeTriggerBot() {
      if (state.players.isEmpty) return;
      if (state.currentPlayerIndex == 0) return; // joueur humain
      if (state.isPaused) return; // Jeu en pause (CHECKS affiché)

      // Délai selon la vitesse configurée dans les paramètres
      final delayMs = GameSettingsService.instance.botDelayMs;

      Future.delayed(Duration(milliseconds: delayMs), () {
        // sécurité: re-vérifier que c'est toujours un bot et que le jeu n'est pas en pause
        if (state.players.isNotEmpty && state.currentPlayerIndex != 0 && !state.isPaused) {
          add(const BotActionRequested());
        }
      });
    }
    // lib/Bloc/checkgames_bloc.dart (suite)

    void _onBotAction(BotActionRequested event, Emitter<CheckgamesState> emit) {
      if (state.players.isEmpty || state.isGameOver) return;

      final idx = state.currentPlayerIndex;
      if (idx == 0) return; // Sécurité : ne pas agir si c'est l'humain

      final me = state.players[idx];
      final strategy = BotStrategyService.instance;

      // --- 1) GESTION DES ATTAQUES (7 / JOKER) ---
      if (state.cardsToDraw > 0) {
        // Le bot utilise la stratégie pour décider s'il contre
        final counter = strategy.decideCounterAttack(
          hand: me.hand,
          topCard: state.discardPile.last,
          imposedSuit: state.imposedSuit,
          cardsToDraw: state.cardsToDraw,
        );

        if (counter != null) {
          add(PlayCard(playerId: me.id, cards: [counter]));
          return;
        }

        // Il ne peut pas ou ne veut pas contrer -> il subit la punition
        add(EndTurn(playerId: me.id));
        return;
      }

      // --- 2) ANALYSE DES CARTES JOUABLES (HORS ATTAQUE) ---
      final top = state.discardPile.last;
      final playable = me.hand.where((c) =>
          RuleEngine.canPlayCard(
              cardToPlay: c,
              topCard: top,
              imposedSuit: state.imposedSuit
          )
      ).toList();

      if (playable.isEmpty) {
        // Le bot pioche une carte
        add(DrawCard(playerId: me.id, count: 1));
        return;
      }

      // --- 3) STRATÉGIE DE JEU (SÉLECTION selon la difficulté) ---
      final selected = strategy.selectCardToPlay(
        hand: me.hand,
        playableCards: playable,
        allPlayers: state.players,
        currentPlayerIndex: idx,
      );

      // --- 4) GESTION DES DOUBLES (selon la difficulté) ---
      final toPlay = strategy.decideMultipleCards(
        selectedCard: selected,
        hand: me.hand,
      );

      // --- 5) CHOIX DE LA COULEUR (VALET - selon la difficulté) ---
      CardSuit? imposed;
      if (selected.value == CardValue.jack) {
        imposed = strategy.selectImposedSuit(
          hand: me.hand,
          allPlayers: state.players,
          currentPlayerIndex: idx,
        );
      }

      // --- 6) ACTION FINALE ---
      add(PlayCard(
          playerId: me.id,
          cards: toPlay,
          imposedSuit: imposed
      ));
    }
    List<Player> _activePlayers(List<Player> all, List<String> finishedIds) {
      return all.where((p) => !finishedIds.contains(p.id)).toList();
    }

    void _startDuel(Emitter<CheckgamesState> emit, List<Player> playersInDuel) {
      // Nouveau paquet, on ne donne la main qu’aux 2 duellistes ; les autres ont 0 carte
      final deck = DeckGenerator.generateFullDeck()..shuffle();

      final updated = state.players.map((p) {
        if (playersInDuel.any((d) => d.id == p.id)) {
          final hand = deck.take(5).toList(); // ou 7/initial selon ta règle
          deck.removeRange(0, 5);
          return p.copyWith(hand: hand);
        }
        return p.copyWith(hand: const []); // ils ont déjà terminé
      }).toList();

      // Utiliser une carte non-spéciale pour commencer le duel
      final firstCard = _drawFirstNonSpecial(deck);
      final discard = [firstCard];
      final firstIndex = updated.indexWhere((p) => p.id == playersInDuel.first.id);

      emit(state.copyWith(
        players: updated,
        drawPile: deck,
        discardPile: discard,
        currentPlayerIndex: firstIndex >= 0 ? firstIndex : 0,
        cardsToDraw: 0,
        skipCount: 0,
        imposedSuit: null,
        phase: GamePhase.duel,
      ));
    }

    PlayingCard _drawFirstNonSpecial(List<PlayingCard> deck) {
      while (deck.isNotEmpty) {
        final c = deck.removeAt(0);
        if (c.value != CardValue.ace &&
            c.value != CardValue.two &&
            c.value != CardValue.seven &&
            c.value != CardValue.jack &&
            c.value != CardValue.joker) {
          return c;
        }
        // Remettre la carte spéciale au fond du deck
        deck.add(c);
      }
      // fallback (au cas où)
      return PlayingCard(suit: CardSuit.hearts, value: CardValue.five);
    }

  /// Récupère le joueur courant de manière sécurisée avec validation d'index
  Player? _getCurrentPlayer() {
    if (state.players.isEmpty) return null;
    if (state.currentPlayerIndex < 0 || state.currentPlayerIndex >= state.players.length) {
      return null;
    }
    return state.players[state.currentPlayerIndex];
  }

  /// Met le jeu en pause ou le reprend
  void _onSetPaused(SetPaused event, Emitter<CheckgamesState> emit) {
    emit(state.copyWith(isPaused: event.isPaused));

    // Si on reprend le jeu, relancer le bot si c'est son tour
    if (!event.isPaused) {
      _maybeTriggerBot();
    }
  }
}