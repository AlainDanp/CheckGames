import 'package:checkgames/models/card_suit.dart';
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
      final currentPlayer = state.players.firstWhere((p) => p.id == event.playerId);
      final cards = event.cards;

      //  Vérifie que les cartes appartiennent au joueur
      if (!cards.every((c) => currentPlayer.hand.contains(c))) return;

      //  Vérifie que toutes les cartes ont la même valeur
      final sameValue = cards.every((c) => c.value == cards.first.value);
      if (!sameValue) return;

      //  La 1re carte doit être jouable (couleur, valeur, ou 2)
      final canPlay = RuleEngine.canPlayCard(
        cardToPlay: cards.first,
        topCard: state.discardPile.last,
        imposedSuit: state.imposedSuit,
      );
      if (!canPlay) return;

      // 🧤 Mise à jour de la main du joueur
      final updatedHand = [...currentPlayer.hand];
      cards.forEach(updatedHand.remove);

      final updatedPlayers = state.players.map((p) {
        return p.id == currentPlayer.id
            ? p.copyWith(hand: updatedHand)
            : p;
      }).toList();

      // ♻️ Ajoute toutes les cartes jouées dans la pile
      final updatedDiscardPile = [...state.discardPile, ...cards];

      // 🔁 Gestion des effets spéciaux (uniquement sur la 1re carte)
      int skip = 0;
      int draw = 0;
      CardSuit? imposedSuit;

      final firstCard = cards.first;
      switch (firstCard.value) {
        case CardValue.ace:
          skip = 1;
          break;
        case CardValue.seven:
          draw = 2;
          break;
        case CardValue.joker:
          draw = 4;
          break;
        case CardValue.jack:
          imposedSuit = event.imposedSuit;
          break;
        default:
          break;
      }

      // 🎯 Passe au joueur suivant (en tenant compte de skip)
      final nextIndex = (state.currentPlayerIndex + 1 + skip) % state.players.length;

      emit(state.copyWith(
        players: updatedPlayers,
        discardPile: updatedDiscardPile,
        currentPlayerIndex: nextIndex,
        skipCount: skip,
        cardsToDraw: draw,
        imposedSuit: imposedSuit,
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
      int nextIndex = (state.currentPlayerIndex + 1 + state.skipCount) % state.players.length;
      final nextPlayer = state.players[nextIndex];

      List<PlayingCard> drawPile = List<PlayingCard>.from(state.drawPile);
      List<PlayingCard> discardPile = List<PlayingCard>.from(state.discardPile);

      // Si deck vide, recycle discardPile sauf la carte visible
      if (drawPile.isEmpty && discardPile.length > 1) {
        final lastCard = discardPile.removeLast();
        drawPile = List<PlayingCard>.from(discardPile)..shuffle();
        discardPile = [lastCard];
      }

      //  Gestion des effets de pioche (7 ou joker)
      List<PlayingCard> drawnCards = [];
      if (state.cardsToDraw > 0) {
        for (int i = 0; i < state.cardsToDraw && drawPile.isNotEmpty; i++) {
          drawnCards.add(drawPile.removeAt(0));
        }
      }

      // Mise à jour du joueur avec les cartes piochées
      final updatedPlayers = state.players.map((p) {
        if (p.id == nextPlayer.id && drawnCards.isNotEmpty) {
          return p.copyWith(hand: [...p.hand, ...drawnCards]);
        }
        return p;
      }).toList();

      //  Nouvelle vérification : peut-il jouer après avoir pioché ?
      final effectiveHand = nextPlayer.hand + drawnCards;
      final canPlay = RuleEngine.playerHasPlayableCard(
        hand: effectiveHand,
        topCard: discardPile.last,
        imposedSuit: state.imposedSuit,
      );

      if (!canPlay) {
        // Pioche supplémentaire si rien à jouer
        PlayingCard? extraCard;
        if (drawPile.isNotEmpty) {
          extraCard = drawPile.removeAt(0);
        }

        final updatedAfterExtra = updatedPlayers.map((p) {
          if (p.id == nextPlayer.id && extraCard != null) {
            return p.copyWith(hand: [...p.hand, extraCard]);
          }
          return p;
        }).toList();

        emit(state.copyWith(
          currentPlayerIndex: (nextIndex + 1) % state.players.length,
          players: updatedAfterExtra,
          drawPile: drawPile,
          discardPile: discardPile,
          cardsToDraw: 0,
          skipCount: 0,
          imposedSuit: null,
        ));
      } else {
        emit(state.copyWith(
          currentPlayerIndex: nextIndex,
          players: updatedPlayers,
          drawPile: drawPile,
          discardPile: discardPile,
          cardsToDraw: 0,
          skipCount: 0,
          imposedSuit: null,
        ));
      }
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