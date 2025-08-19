import '../models/card_suit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/player_card.dart';
import '../models/playing_card.dart';
import '../logic/deckgenerator.dart';
import '../logic/rule_engine.dart';
import '../models/card_value.dart';

import 'checkgames_event.dart';
import 'checkgames_state.dart';

class CheckGameBloc extends Bloc<CheckgamesEvent, CheckgamesState>{
    CheckGameBloc() : super(const CheckgamesState()){
      on<StartGame>(_onStartGame);
      on<PlayCard>(_onPlayCard);
      on<DrawCard>(_onDrawCard);
      on<EndTurn>(_onEndTurn);
      on<RestartGame>(_onRestartGame);

      on<BotActionRequested>(_onBotAction);
    }

    ///Démarrage du jeu;
    void _onStartGame(StartGame event, Emitter<CheckgamesState> emit){
      final deck = DeckGenerator.generateFullDeck()..shuffle();
      final player = event.playerNames.asMap().entries.map((entry){
        final id = entry.key.toString();
        final name = entry.value;
        final hand = deck.sublist(id.length * 5, id.length * 5 + 5);
        return Player(id: id, name: name, hand: hand);
      }).toList();

      final disard = [deck[deck.length - 1]];
      final draw = deck.sublist(0, deck.length - 1);

      emit(CheckgamesState(
        players: player,
        drawPile: draw,
        discardPile: disard,
        currentPlayerIndex: 0,
        phase: GamePhase.normal,
        finishingOrder: const [],
      ));
      _maybeTriggerBot();
    }

    /// Jouer une carte si autorisé
    void _onPlayCard(PlayCard event, Emitter<CheckgamesState> emit) {
      if (state.players.isEmpty) return;
      if (state.players[state.currentPlayerIndex].id != event.playerId) return;
      if (event.cards.isEmpty) return;

      final currentPlayer = state.players[state.currentPlayerIndex];
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

      if (!canPlay) return;



      // mise à jour main
      final newHand = [...currentPlayer.hand]..removeWhere(cards.contains);
      final players = state.players.map((p) =>
      p.id == currentPlayer.id ? p.copyWith(hand: newHand) : p
      ).toList();

      // défausse
      final discard = [...state.discardPile, ...cards];

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

      // si une carte NON-J a été jouée ET qu’elle MATCHE la couleur imposée,
      // on consomme l’imposition (elle a été respectée)
      if (state.imposedSuit != null &&
          first.value != CardValue.jack &&
          first.suit == state.imposedSuit) {
        imposed = null;
      }

      final nextIndex = (state.currentPlayerIndex + 1 + skip) % state.players.length;

      // victoire si main vide
      bool over = false;
      List<String> order = List.of(state.finishingOrder);
      if (newHand.isEmpty) {
        over = true;
        order.add(currentPlayer.id);
      }

      emit(state.copyWith(
        players: players,
        discardPile: discard,
        currentPlayerIndex: over ? state.currentPlayerIndex : nextIndex, // si fin, on ne bouge plus
        skipCount: 0,
        cardsToDraw: draw,
        imposedSuit: imposed,
        isGameOver: over,
        finishingOrder: order,
      ));

      if (!over) _maybeTriggerBot();
    }

    /// piocher des cartes
    void _onDrawCard(DrawCard event, Emitter<CheckgamesState> emit) {
      final me = state.players.firstWhere((p) => p.id == event.playerId, orElse: () => state.players.first);
      if (me.id != state.players[state.currentPlayerIndex].id) return; // pas son tour

      // si cumulus actif, ignorer DrawCard manuel (la pioche se fait dans EndTurn)
      if (state.cardsToDraw > 0) return;

      final count = event.count;
      final drawPile = List<PlayingCard>.from(state.drawPile);
      final drawn = <PlayingCard>[];

      // recycle si vide
      var discard = List<PlayingCard>.from(state.discardPile);
      if (drawPile.isEmpty && discard.length > 1) {
        final top = discard.removeLast();
        drawPile.addAll(discard..shuffle());
        discard = [top];
      }

      for (int i = 0; i < count && drawPile.isNotEmpty; i++) {
        drawn.add(drawPile.removeAt(0));
      }

      final players = state.players.map((p) {
        if (p.id == me.id) {
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
      final currentPlayer = state.players[currentIndex];

      var drawPile = List<PlayingCard>.from(state.drawPile);
      var discard  = List<PlayingCard>.from(state.discardPile);

      // Recyclage si la pioche est vide
      if (drawPile.isEmpty && discard.length > 1) {
        final top = discard.removeLast();
        drawPile = List.of(discard)..shuffle();
        discard = [top];
      }

      //  Cas effet cumulé (7/joker) : la pioche s’applique au JOUEUR COURANT
      if (state.cardsToDraw > 0) {
        final drawn = <PlayingCard>[];
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
        deck.removeRange(0, 5);
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
      // petite latence pour laisser l’UI respirer
      Future.delayed(const Duration(milliseconds: 300), () {
        // sécurité: re-vérifier que c'est toujours un bot
        if (state.players.isNotEmpty && state.currentPlayerIndex != 0) {
          add(const BotActionRequested());
        }
      });
    }
    // lib/Bloc/checkgames_bloc.dart (suite)

    void _onBotAction(BotActionRequested event, Emitter<CheckgamesState> emit) {
      if (state.players.isEmpty) return;
      final idx = state.currentPlayerIndex;
      if (idx == 0) return; // pas un bot
      final me = state.players[idx];

      // 1) S'il y a une pénalité en attente, le bot tente de contrer (7/joker); sinon il subit.
      if (state.cardsToDraw > 0) {
        final canCounter = me.hand.any((c) =>
        (c.value == CardValue.seven) || (c.value == CardValue.joker));
        if (canCounter) {
          // joue un 7 en priorité, sinon un joker
          final seven = me.hand.firstWhere(
                (c) => c.value == CardValue.seven,
            orElse: () => const PlayingCard(suit: CardSuit.hearts, value: CardValue.ace), // dummy
          );
          if (seven.value == CardValue.seven &&
              RuleEngine.canPlayCard(
                cardToPlay: seven,
                topCard: state.discardPile.last,
                imposedSuit: state.imposedSuit,
              )) {
            add(PlayCard(playerId: me.id, cards: [seven]));
            return;
          }
          final anyJoker = me.hand.firstWhere(
                (c) => c.value == CardValue.joker,
            orElse: () => const PlayingCard(suit: CardSuit.hearts, value: CardValue.ace),
          );
          if (anyJoker.value == CardValue.joker &&
              RuleEngine.canPlayCard(
                cardToPlay: anyJoker,
                topCard: state.discardPile.last,
                imposedSuit: state.imposedSuit,
              )) {
            add(PlayCard(playerId: me.id, cards: [anyJoker]));
            return;
          }
        }
        // ne peut pas contrer → subir la pioche (EndTurn appliquera cardsToDraw)
        add(EndTurn());
        return;
      }

      // 2) Liste des cartes jouables
      final top = state.discardPile.last;
      final playable = me.hand.where((c) =>
          RuleEngine.canPlayCard(cardToPlay: c, topCard: top, imposedSuit: state.imposedSuit)
      ).toList();

      if (playable.isEmpty) {
        // Règle: pas de coup → le bot passe son tour (EndTurn gère la pioche 1 et avance)
        add(EndTurn());
        return;
      }

      // 3) Double coup : s'il a plusieurs cartes de même valeur, il essaie de toutes les jouer
      List<PlayingCard> toPlay = [playable.first];
      final value = toPlay.first.value;
      final sameValueRest = me.hand.where((c) => c.value == value && c != toPlay.first).toList();
      if (sameValueRest.isNotEmpty) {
        // attention: la 1re doit être jouable; les suivantes suivent par valeur
        toPlay = [toPlay.first, ...sameValueRest];
      }

      // 4) Si la 1re est un Valet → choisir une couleur à imposer (celle où il a le plus de cartes)
      CardSuit? imposed;
      if (value == CardValue.jack) {
        imposed = _bestSuitToImpose(me.hand);
      }

      add(PlayCard(playerId: me.id, cards: toPlay, imposedSuit: imposed));
    }

    CardSuit _bestSuitToImpose(List<PlayingCard> hand) {
      final counts = <CardSuit, int>{
        CardSuit.hearts: 0, CardSuit.diamonds: 0, CardSuit.clubs: 0, CardSuit.spades: 0,
      };
      for (final c in hand) {
        if (counts.containsKey(c.suit)) {
          counts[c.suit] = (counts[c.suit] ?? 0) + 1;
        }
      }
      // choisir la couleur max; fallback ♥
      CardSuit suit = CardSuit.hearts;
      int best = -1;
      counts.forEach((s, n) { if (n > best) { best = n; suit = s; }});
      return suit;
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

      final discard = [deck.removeAt(0)];
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
        // sinon on met la carte au fond
      }
      // fallback (au cas où)
      return PlayingCard(suit: CardSuit.hearts, value: CardValue.five);
    }
}