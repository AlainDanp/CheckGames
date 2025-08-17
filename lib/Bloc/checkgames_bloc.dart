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
    }
    ///Démarrage du jeu;
    void _onStartGame(StartGame event, Emitter<CheckgamesState> emit){
      final deck = DeckGenerator.shuffledDeck();
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
      ));
    }

    /// Jouer une carte si autorisé
    void _onPlayCard(PlayCard event, Emitter<CheckgamesState> emit) {

      if (event.cards.isEmpty) return;
      // Refuse si ce n’est pas le tour de ce player
      if (state.players.isEmpty || state.players[state.currentPlayerIndex].id != event.playerId) {
        return;
      }

      final currentPlayer = state.players.firstWhere((p) => p.id == event.playerId);
      final cards = event.cards;

      // Vérifie que les cartes appartiennent au joueur
      if (!cards.every((c) => currentPlayer.hand.contains(c))) return;
      // Vérifie que toutes les cartes ont la même valeur
      if (!cards.every((c) => c.value == cards.first.value)) return;

      // final sameValue = cards.every((c) => c.value == cards.first.value);
      // if (!sameValue) return;

      // La 1re carte doit être jouable
      final canPlay = RuleEngine.canPlayCard(
        cardToPlay: cards.first,
        topCard: state.discardPile.last,
        imposedSuit: state.imposedSuit,
      );
      if (!canPlay) return;

      // Mise à jour de la main
      final updatedHand = [...currentPlayer.hand];
      // cards.forEach(updatedHand.remove);
      for (final c in cards){
        updatedHand.remove(c);
      }

      final updatedPlayers = state.players.map((p) =>
      p.id == currentPlayer.id ? p.copyWith(hand: updatedHand) : p).toList();

      // Ajoute les cartes jouées dans la défausse
      final updatedDiscardPile = [...state.discardPile, ...cards];

      // Gestion des effets cumulés
      int skip = 0;
      int draw = state.cardsToDraw;
      CardSuit? imposedSuit = state.imposedSuit;


      for (final card in cards) {
        switch (card.value) {
          case CardValue.ace:
            skip += 1;
            break;
          case CardValue.seven:
            draw += 2  ;
           // waitForResponse = true;
            break;
          case CardValue.joker:
            draw += 4 ;
           // waitForResponse = true;
            break;
          case CardValue.jack:
            if(event.imposedSuit == null) return;
            imposedSuit = event.imposedSuit;
            // waitForResponse = true;
            break;
          default: break;
        }
      }

      final first = cards.first;

      if(first.value != CardValue.jack && state.imposedSuit != null){
        imposedSuit = null;
      }
      print(' Nouvelle valeur de cardsToDraw: $draw');

      final nextIndex = (state.currentPlayerIndex + 1 + skip) % state.players.length;

      final firstCard = cards.first;
      final isStackable = firstCard.value == CardValue.seven || firstCard.value == CardValue.joker;
      final nextPlayer = state.players[nextIndex];

      final nextCanCounter = isStackable && nextPlayer.hand.any((c) => c.value == firstCard.value);
      final waitForResponse = isStackable && nextCanCounter;

      emit(state.copyWith(
        players: updatedPlayers,
        discardPile: updatedDiscardPile,
        currentPlayerIndex: nextIndex,
        skipCount: 0,
        cardsToDraw: draw,
        imposedSuit: imposedSuit,
        shouldWaitForResponse: waitForResponse,
      ));
    }


    /// piocher des cartes
    void _onDrawCard(DrawCard event, Emitter<CheckgamesState> emit){
      final player = state.players.firstWhere((p) => p.id == event.playerId);
      final drawn = state.drawPile.take(event.count).toList();
      final newDrawPile = state.drawPile.sublist(event.count);

      final updatedPlayers = state.players.map((p) {
        if (p.id == player.id) {
          return p.copyWith(hand: [...p.hand, ...drawn]);
        }
        return p;
      }).toList();

      emit(state.copyWith(
        players: updatedPlayers,
        drawPile: newDrawPile,
        cardsToDraw: 0,
      ));

    }
    /// Passer au joueur suivant
    void _onEndTurn(EndTurn event, Emitter<CheckgamesState> emit) {
      final n = state.players.length;
      if (n == 0) return;

      final currentIndex = state.currentPlayerIndex;
      final currentPlayer = state.players[currentIndex];

      List<PlayingCard> drawPile = List.of(state.drawPile);
      List<PlayingCard> discard  = List.of(state.discardPile);


      // Recyclage si la pioche est vide
      if (drawPile.isEmpty && discard.length > 1) {
        final last = discard.removeLast();
        drawPile = List<PlayingCard>.from(discard)..shuffle();
        discard = [last];
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
          cardsToDraw: 0,                                  // reset
          skipCount: 0,
          imposedSuit: state.imposedSuit,
          currentPlayerIndex: (currentIndex + 1) % n, // avance après pioche
        ));
        return; //  pas de "carte bonus" dans ce cas
      }

      //  Cas normal (pas d’effet en attente) : on regarde si le prochain peut jouer, sinon il pioche 1
      final nextIndex = (currentIndex + 1 + state.skipCount) % n;
      final nextPlayer = state.players[nextIndex];

      // Peut-il jouer ?
      final canPlay = RuleEngine.playerHasPlayableCard(
        hand: nextPlayer.hand,
        topCard: state.discardPile.last,
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
      final newIndex =
      (!canPlay) ? (nextIndex + 1) % n   // il a pioché → on saute à l’autre
          : nextIndex;             // il peut jouer → on s’arrête sur lui


      emit(state.copyWith(
        players: updatedPlayers,
        drawPile: drawPile,
        cardsToDraw: 0,
        skipCount: 0,
        imposedSuit: state.imposedSuit,
        currentPlayerIndex: nextIndex,
      ));
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

      final discardPile = [deck.removeAt(0)];

      emit(CheckgamesState(
        players: updatedPlayers,
        drawPile: deck,
        discardPile: discardPile,
        currentPlayerIndex: 0,
        skipCount: 0,
        imposedSuit: null,
        isGameOver: false,
      ));
    }
}