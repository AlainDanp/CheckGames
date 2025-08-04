import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:checkgames/Bloc/checkgames_bloc.dart';
import 'package:checkgames/Bloc/checkgames_state.dart';
import 'package:checkgames/Bloc/checkgames_event.dart';
import 'package:checkgames/models/playing_card.dart';
import 'package:checkgames/models/card_value.dart';
import 'package:checkgames/models/card_suit.dart';
import 'package:checkgames/models/player_card.dart';
import 'package:checkgames/logic/rule_engine.dart';

void main() {
  group('Check - RestartGame', () {
    test('should reset game state and redistribute cards to existing players', () async {
      final bloc = CheckGameBloc();

      // Étape 1 : Démarrer une partie avec 2 joueurs
      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero); // Attendre l'état

      final oldPlayers = bloc.state.players;
      expect(oldPlayers.length, 2);

      final oldHands = oldPlayers.map((p) => p.hand).toList();

      // Étape 2 : Relancer la partie avec les mêmes joueurs
      bloc.add(RestartGame(keepPlayers: true));
      await Future.delayed(Duration.zero);

      final newState = bloc.state;

      // Vérifier que les mêmes joueurs sont conservés
      expect(newState.players.length, 2);
      expect(newState.currentPlayerIndex, 0);
      expect(newState.skipCount, 0);
      expect(newState.cardsToDraw, 0);
      expect(newState.imposedSuit, isNull);
      expect(newState.isGameOver, false);

      // Chaque joueur doit avoir 5 cartes
      for (final player in newState.players) {
        expect(player.hand.length, 5);
      }

      // Le deck (pioche) et le discardPile doivent être non vides
      expect(newState.drawPile.length, greaterThan(0));
      expect(newState.discardPile.length, equals(1));

      // Vérifie que les nouvelles mains sont différentes des anciennes
      final newHands = newState.players.map((p) => p.hand).toList();
      expect(newHands, isNot(equals(oldHands)));
    });
    test('EndTurn - player unable to play draws a card and turn passes', () async {
      final bloc = CheckGameBloc();

      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);


      final topCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.three);

      final forcedBob = bloc.state.players[1].copyWith(hand: [
        PlayingCard(suit: CardSuit.clubs, value: CardValue.nine),
        PlayingCard(suit: CardSuit.clubs, value: CardValue.jack),
      ]);

      final forcedPlayers = [
        bloc.state.players[0],
        forcedBob,
      ];

      final forcedDrawPile = List<PlayingCard>.from(bloc.state.drawPile);
      final bobHandBefore = forcedBob.hand.length;

      bloc.emit(bloc.state.copyWith(
        players: forcedPlayers,
        currentPlayerIndex: 0, // Tour d'Alice
        discardPile: [topCard],
        drawPile: forcedDrawPile,
      ));


      bloc.add(EndTurn(playerId: '1'));
      await Future.delayed(Duration.zero);

      final newState = bloc.state;
      final bobAfter = newState.players[1];


      expect(bobAfter.hand.length, equals(bobHandBefore + 1));


      expect(newState.currentPlayerIndex, equals(0));


      expect(newState.skipCount, equals(0));
      expect(newState.imposedSuit, isNull);
    });
    test('EndTurn - next player can play, no draw, turn passes correctly', () async {
      final bloc = CheckGameBloc();

      // Étape 1 : Démarrer une partie avec deux joueurs
      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      final topCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.five);

      // Bob a une carte jouable : même couleur
      final bobPlayableCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.nine);

      final updatedPlayers = [
        bloc.state.players[0],
        bloc.state.players[1].copyWith(hand: [bobPlayableCard]),
      ];

      bloc.emit(bloc.state.copyWith(
        players: updatedPlayers,
        currentPlayerIndex: 0,
        discardPile: [topCard],
        skipCount: 0,
        imposedSuit: null,
      ));


      bloc.add(EndTurn(playerId: '1'));
      await Future.delayed(Duration.zero);

      final newState = bloc.state;

      expect(newState.currentPlayerIndex, equals(1));


      expect(newState.players[1].hand.length, equals(1));
      expect(newState.players[1].hand.first, equals(bobPlayableCard));


      expect(newState.skipCount, equals(0));
      expect(newState.imposedSuit, isNull);
    });
    test('PlayCard - Valet impose une couleur', () async {
      final bloc = CheckGameBloc();

      // Démarrer la partie
      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      final jackCard = PlayingCard(suit: CardSuit.spades, value: CardValue.jack);
      final topCard = PlayingCard(suit: CardSuit.spades, value: CardValue.ten);

      // Donner à Alice un valet
      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        players: [
          bloc.state.players[0].copyWith(hand: [jackCard]),
          bloc.state.players[1],
        ],
      ));

      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [jackCard], imposedSuit: CardSuit.hearts));
      await Future.delayed(Duration.zero);

      final newState = bloc.state;
      expect(newState.discardPile.last, equals(jackCard));
      expect(newState.imposedSuit, equals(CardSuit.hearts));
      expect(newState.players[0].hand.contains(jackCard), isFalse);
    });
    test('PlayCard - 7 fait piocher 2 cartes au joueur suivant', () async {
      final bloc = CheckGameBloc();

      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      final sevenCard = PlayingCard(suit: CardSuit.spades, value: CardValue.seven);
      final topCard = PlayingCard(suit: CardSuit.spades, value: CardValue.nine);

      final updatedPlayers = [
        bloc.state.players[0].copyWith(hand: [sevenCard]),
        bloc.state.players[1],
      ];

      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        players: [
          bloc.state.players[0].copyWith(hand: [sevenCard]),
          bloc.state.players[1],
        ],
      ));
      // Alice joue le 7
      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [sevenCard]));
      await Future.delayed(Duration.zero);

      final afterPlay = bloc.state;
      expect(afterPlay.currentPlayerIndex, equals(1));
      expect(afterPlay.cardsToDraw, equals(2));
    });

    test('PlayCard - Joker fait piocher 4 cartes au joueur suivant', () async {
      final bloc = CheckGameBloc();

      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      final jokerCard = PlayingCard(suit: CardSuit.joker, value: CardValue.joker);

      // Donne à Alice uniquement le Joker
      final updatedPlayers = [
        bloc.state.players[0].copyWith(hand: [jokerCard]),
        bloc.state.players[1],
      ];
      bloc.emit(bloc.state.copyWith(players: updatedPlayers));

      // Alice joue le Joker et impose "carreau"
      bloc.add(PlayCard(
        playerId: updatedPlayers[0].id,
        cards: [jokerCard],
        imposedSuit: CardSuit.diamonds,
      ));
      await Future.delayed(Duration.zero);

      // Bob termine son tour, il doit piocher 4 cartes
      bloc.add(EndTurn(playerId: bloc.state.players[1].id));

      await Future.delayed(Duration.zero);

      final newBob = bloc.state.players[1];

      // Bob a bien pioché 4 cartes
      expect(newBob.hand.length, greaterThanOrEqualTo(4));

      // imposedSuit a été reset après le tour
      expect(bloc.state.imposedSuit, isNull);

      // cardsToDraw a été reset
      expect(bloc.state.cardsToDraw, equals(0));
    });
    test('PlayCard - Valet impose une couleur au joueur suivant', () async {
      final bloc = CheckGameBloc();

      // Démarre une partie avec 2 joueurs
      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      final jackCard = PlayingCard(suit: CardSuit.clubs, value: CardValue.jack);
      final topCard = PlayingCard(suit: CardSuit.clubs, value: CardValue.king);

      // Donne à Alice uniquement le Valet de ♠
      final updatedPlayers = [
        bloc.state.players[0].copyWith(hand: [jackCard]),
        bloc.state.players[1],
      ];
      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        players: [
          bloc.state.players[0].copyWith(hand: [jackCard]),
          bloc.state.players[1],
        ],
      ));
      // Alice joue le Valet et impose la couleur ♣
      bloc.add(PlayCard(
        playerId: bloc.state.players[0].id,
        cards: [jackCard],
        imposedSuit: CardSuit.clubs,
      ));
      await Future.delayed(Duration.zero);

      expect(bloc.state.imposedSuit, equals(CardSuit.clubs));
      expect(bloc.state.discardPile.last, equals(jackCard));
      expect(bloc.state.currentPlayerIndex, equals(1));
    });

    test('Le deux ', () async  {
      final topCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.king);
      final deuxTrefle = PlayingCard(suit: CardSuit.clubs, value: CardValue.two);
      final deuxPique = PlayingCard(suit: CardSuit.spades, value: CardValue.two);

      final peutJouer1 = RuleEngine.canPlayCard(
        cardToPlay: deuxTrefle,
        topCard: topCard,
        imposedSuit: null,
      );

      final peutJouer2 = RuleEngine.canPlayCard(
        cardToPlay: deuxPique,
        topCard: topCard,
        imposedSuit: null,
      );

      expect(peutJouer1, isTrue);
      expect(peutJouer2, isTrue);
    });
    test('Double coup', () async {
      final bloc = CheckGameBloc();

      // Démarre une partie avec 2 joueurs
      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      // Création de deux cartes de même valeur (deux 6)
      final card1 = PlayingCard(suit: CardSuit.diamonds, value: CardValue.six); // 6♦
      final card2 = PlayingCard(suit: CardSuit.clubs, value: CardValue.six);   // 6♣
      final topCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.six); // 6♥

      // Met à jour la pile et la main d'Alice
      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        players: [
          bloc.state.players[0].copyWith(hand: [card1, card2]),
          bloc.state.players[1],
        ],
      ));

      // Alice joue les deux 6
      bloc.add(PlayCard(
        playerId: bloc.state.players[0].id,
        cards: [card2, card1],
      ));
      await Future.delayed(Duration.zero);

      // Vérifie que les deux cartes ont été jouées (dans l'ordre attendu ici)
      expect(bloc.state.discardPile[bloc.state.discardPile.length - 2], equals(card2));
      expect(bloc.state.discardPile.last, equals(card1));

      //  Vérifie que la main est vide
      expect(bloc.state.players[0].hand.length, equals(0));

      //  Tour suivant : Bob
      expect(bloc.state.currentPlayerIndex, equals(1));
    });



  });
}
