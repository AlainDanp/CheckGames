import 'package:checkgame/logic/deckgenerator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:checkgame/Bloc/checkgames_bloc.dart';
import 'package:checkgame/Bloc/checkgames_state.dart';
import 'package:checkgame/Bloc/checkgames_event.dart';
import 'package:checkgame/models/playing_card.dart';
import 'package:checkgame/models/card_value.dart';
import 'package:checkgame/models/card_suit.dart';
import 'package:checkgame/models/player_card.dart';
import 'package:checkgame/logic/rule_engine.dart';


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
    test('EndTurn1 - player unable to play draws a card and turn passes', () async {
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


      bloc.add(EndTurn());
      await Future.delayed(Duration.zero);

      final newState = bloc.state;
      final bobAfter = newState.players[1];


      expect(bobAfter.hand.length, equals(bobHandBefore + 1));


      expect(newState.currentPlayerIndex, equals(1));


      expect(newState.skipCount, equals(0));
      expect(newState.imposedSuit, isNull);
    });
    test('EndTurn2 - next player can play, no draw, turn passes correctly', () async {
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


      bloc.add(EndTurn());

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

      final jokerCard = PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker);
      final topCard = PlayingCard(suit: CardSuit.diamonds, value: CardValue.five);


      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        players: [
          bloc.state.players[0].copyWith(hand: [jokerCard]),
          bloc.state.players[1],
        ],
      ));

      // Alice joue le joker
      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [jokerCard]));
      await Future.delayed(Duration.zero);

      final afterPlay = bloc.state;
      expect(afterPlay.currentPlayerIndex, equals(1));
      expect(afterPlay.cardsToDraw, equals(4));

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
    test('PlayCard - Double joker fait piocher' , () async {
        final bloc = CheckGameBloc();

        bloc.add(StartGame(['Alain', 'Bob', 'Claire']));
        await Future.delayed(Duration.zero);

        final joker1 = PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker);
        final joker2 = PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker);
        final topCard = PlayingCard(suit: CardSuit.diamonds, value: CardValue.five);

        final drawPile = List<PlayingCard>.generate(
          20,
              (index) => PlayingCard(
            suit: CardSuit.spades,
            value: CardValue.values[index % CardValue.values.length],
          ),
        );


        bloc.emit(bloc.state.copyWith(
          discardPile: [topCard],
          drawPile: drawPile,
          players: [
            bloc.state.players[0].copyWith(hand: [joker1]),
            bloc.state.players[1].copyWith(hand: [joker2]),
            bloc.state.players[2].copyWith(hand: []), // Claire ne possède pas de joker
          ],
          currentPlayerIndex: 0,
        ));

        // Alain joue un joker
        bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [joker1]));
        await Future.delayed(Duration.zero);
        expect(bloc.state.cardsToDraw, equals(4));
        expect(bloc.state.currentPlayerIndex, equals(1));

        print('Après Alain : cardsToDraw = ${bloc.state.cardsToDraw}');
        // Bob répond avec un joker aussi

        bloc.add(PlayCard(playerId: bloc.state.players[1].id, cards: [joker2]));
        await Future.delayed(Duration.zero);
        expect(bloc.state.cardsToDraw, equals(8));
        expect(bloc.state.currentPlayerIndex, equals(2)); // → Claire
        await Future.delayed(Duration.zero);


        print('Après Bob : cardsToDraw = ${bloc.state.cardsToDraw}');

        // Claire ne peut pas répondre, donc elle termine son tour
        bloc.add(EndTurn());
        await Future.delayed(Duration.zero);

        print('Claire a maintenant : ${bloc.state.players[2].hand.length} cartes');

        expect(bloc.state.players[2].hand.length, equals(8));
    });

    test('echec si deux cartes differentes', () async {
      final bloc = CheckGameBloc();

      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      final card1 = PlayingCard(suit: CardSuit.hearts, value: CardValue.five);
      final card2 = PlayingCard(suit: CardSuit.clubs, value: CardValue.seven);
      final topCard = PlayingCard(suit: CardSuit.diamonds, value: CardValue.five);

      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        players: [
          bloc.state.players[0].copyWith(hand: [card1, card2]),
          bloc.state.players[1],
        ],
      ));

      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [card1, card2]));
      await Future.delayed(Duration.zero);

      // Les cartes ne doivent pas avoir été jouées (main toujours complète)
      expect(bloc.state.players[0].hand.length, equals(2));
      expect(bloc.state.discardPile.length, equals(1)); // la carte du dessus seulement
    });


    test('PlayCard - Bob prend leffet du joker dAlice et pioche 4 cartes', () async {
      final bloc = CheckGameBloc();

      // Étape 1: démarrer une partie avec Alice et Bob
      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      // Étape 2: Préparation des cartes
      final jokerCard = PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker);
      final topCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.five);
      final bobInitialCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.three);

      // Générer un paquet de 20 cartes pour la pioche
      final drawPile = List<PlayingCard>.generate(
        20,
            (index) => PlayingCard(
          suit: CardSuit.clubs,
          value: CardValue.values[index % CardValue.values.length],
        ),
      );

      // Étape 3: Configuration de l'état initial

      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        drawPile: drawPile,
        players: [
          bloc.state.players[0].copyWith(hand: [jokerCard]),        // Alice
          bloc.state.players[1].copyWith(hand: [bobInitialCard]),   // Bob
        ],
      ));

      // Étape 4: Alice joue le joker
      bloc.add(PlayCard(
        playerId: bloc.state.players[0].id,
        cards: [jokerCard],
      ));

      await Future.delayed(Duration.zero);

      // Étape 5: Bob termine son tour (il n’a pas de joker, donc doit piocher)
      bloc.add(EndTurn());


      await Future.delayed(Duration.zero);

      // Étape 6: Vérification
      final bobFinalHand = bloc.state.players[1].hand;
      print(bobFinalHand);
      // 1 carte initiale + 4 piochées = 5
      expect(bobFinalHand.length, equals(5));
    });


    test('Tour par tour sans joker ni 7', () async {
      final bloc = CheckGameBloc();

      // Initialisation
      bloc.add(StartGame(['Alice', 'Bob', 'Claire']));
      await Future.delayed(Duration.zero);

      final cardA = PlayingCard(suit: CardSuit.hearts, value: CardValue.nine);
      final cardB = PlayingCard(suit: CardSuit.hearts, value: CardValue.eight);
      final cardC = PlayingCard(suit: CardSuit.hearts, value: CardValue.seven);
      final topCard = PlayingCard(suit: CardSuit.hearts, value: CardValue.ten);

      // État initial : tous les joueurs ont une seule carte jouable
      bloc.emit(bloc.state.copyWith(
        discardPile: [topCard],
        players: [
          bloc.state.players[0].copyWith(hand: [cardA]),
          bloc.state.players[1].copyWith(hand: [cardB]),
          bloc.state.players[2].copyWith(hand: [cardC]),
        ],
      ));

      // Alice joue
      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [cardA]));
      await Future.delayed(Duration.zero);
      expect(bloc.state.currentPlayerIndex, equals(1));
      expect(bloc.state.discardPile.last, equals(cardA));
      expect(bloc.state.players[0].hand.length, equals(0));

      // Bob joue
      bloc.add(PlayCard(playerId: bloc.state.players[1].id, cards: [cardB]));
      await Future.delayed(Duration.zero);
      expect(bloc.state.currentPlayerIndex, equals(2));
      expect(bloc.state.discardPile.last, equals(cardB));
      expect(bloc.state.players[1].hand.length, equals(0));

      // Claire joue
      bloc.add(PlayCard(playerId: bloc.state.players[2].id, cards: [cardC]));
      await Future.delayed(Duration.zero);
      expect(bloc.state.currentPlayerIndex, equals(0));
      expect(bloc.state.discardPile.last, equals(cardC));
      expect(bloc.state.players[2].hand.length, equals(0));
    });

    test('Ace (As) skip next player is skipped', () async {
      final bloc = CheckGameBloc();
      bloc.add(StartGame(['Alice', 'Bob', 'Claire']));
      await Future.delayed(Duration.zero);

      final ace = PlayingCard(suit: CardSuit.hearts, value: CardValue.ace);
      final top  = PlayingCard(suit: CardSuit.hearts, value: CardValue.five);

      bloc.emit(bloc.state.copyWith(
        discardPile: [top],
        players: [
          bloc.state.players[0].copyWith(hand: [ace]), // Alice
          bloc.state.players[1],                        // Bob
          bloc.state.players[2],                        // Claire
        ],
        currentPlayerIndex: 0,
      ));

      // Alice joue As => Bob est sauté, tour → Claire
      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [ace]));
      await Future.delayed(Duration.zero);

      expect(bloc.state.currentPlayerIndex, equals(2)); // Claire
    });

    test('Jack on Jack second imposed suit replaces the first', () async {
      final bloc = CheckGameBloc();
      bloc.add(StartGame(['Alice','Bob','Claire']));
      await Future.delayed(Duration.zero);

      final jack1 = PlayingCard(suit: CardSuit.clubs,    value: CardValue.jack);
      final jack2 = PlayingCard(suit: CardSuit.spades,   value: CardValue.jack);
      final top   = PlayingCard(suit: CardSuit.clubs, value: CardValue.five);

      bloc.emit(bloc.state.copyWith(
        discardPile: [top],
        players: [
          bloc.state.players[0].copyWith(hand: [jack1]),
          bloc.state.players[1].copyWith(hand: [jack2]),
          bloc.state.players[2],
        ],
        currentPlayerIndex: 0,
      ));

      // Alice impose ♣
      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [jack1], imposedSuit: CardSuit.clubs));
      await Future.delayed(Duration.zero);
      expect(bloc.state.imposedSuit, equals(CardSuit.clubs));
      expect(bloc.state.currentPlayerIndex, equals(1)); // Bob

      // Bob impose ♠ et remplace l'ancienne imposition
      bloc.add(PlayCard(playerId: bloc.state.players[1].id, cards: [jack2], imposedSuit: CardSuit.spades));
      await Future.delayed(Duration.zero);
      expect(bloc.state.imposedSuit, equals(CardSuit.spades));
      expect(bloc.state.currentPlayerIndex, equals(2)); // Claire
    });

    test('Stack 7s  +2 then +2  third player draws 4', () async {
      final bloc = CheckGameBloc();
      bloc.add(StartGame(['Alice','Bob','Claire']));
      await Future.delayed(Duration.zero);

      final sevenA = PlayingCard(suit: CardSuit.hearts, value: CardValue.seven);
      final sevenB = PlayingCard(suit: CardSuit.clubs,  value: CardValue.seven);
      final top    = PlayingCard(suit: CardSuit.hearts, value: CardValue.five);

      final drawPile = List<PlayingCard>.generate(
        30,
            (i) => PlayingCard(suit: CardSuit.diamonds, value: CardValue.values[i % CardValue.values.length]),
      );

      bloc.emit(bloc.state.copyWith(
        discardPile: [top],
        drawPile: drawPile,
        players: [
          bloc.state.players[0].copyWith(hand: [sevenA]),
          bloc.state.players[1].copyWith(hand: [sevenB]),
          bloc.state.players[2].copyWith(hand: []),
        ],
        currentPlayerIndex: 0,
      ));

      // Alice joue 7 (+2)
      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [sevenA]));
      await Future.delayed(Duration.zero);
      expect(bloc.state.cardsToDraw, equals(2));
      expect(bloc.state.currentPlayerIndex, equals(1));

      // Bob enchaîne 7 (+2) → cumul 4
      bloc.add(PlayCard(playerId: bloc.state.players[1].id, cards: [sevenB]));
      await Future.delayed(Duration.zero);
      expect(bloc.state.cardsToDraw, equals(4));
      expect(bloc.state.currentPlayerIndex, equals(2));

      // Claire ne contre pas : à son EndTurn, elle pioche 4 (pas de carte bonus)
      bloc.add(EndTurn());
      await Future.delayed(Duration.zero);
      expect(bloc.state.players[2].hand.length, equals(4));
    });

    test('No playable card next player draws 1 and turn passes', () async {
      final bloc = CheckGameBloc();
      bloc.add(StartGame(['Alice','Bob']));
      await Future.delayed(Duration.zero);

      final top = PlayingCard(suit: CardSuit.hearts, value: CardValue.five);
      // Bob ne peut pas jouer (ni même valeur, ni même couleur, ni 2)
      final bobHand = [
        PlayingCard(suit: CardSuit.clubs, value: CardValue.seven),
      ];
      final drawPile = List<PlayingCard>.generate(
        5,
            (i) => PlayingCard(suit: CardSuit.spades, value: CardValue.values[i % CardValue.values.length]),
      );

      bloc.emit(bloc.state.copyWith(
        discardPile: [top],
        drawPile: drawPile,
        players: [
          bloc.state.players[0],
          bloc.state.players[1].copyWith(hand: bobHand),
        ],
        currentPlayerIndex: 0,
        cardsToDraw: 0,
      ));

      // Fin du tour d'Alice → c'est à Bob : il ne peut pas jouer ⇒ il pioche 1 et on passe à Alice
      bloc.add(EndTurn());
      await Future.delayed(Duration.zero);

      expect(bloc.state.players[1].hand.length, equals(2)); // 1 + 1 piochée
      expect(bloc.state.currentPlayerIndex, equals(1));
    });

    test('Two is wildcard can be played on any top card', () async {
      final bloc = CheckGameBloc();
      bloc.add(StartGame(['Alice','Bob']));
      await Future.delayed(Duration.zero);

      final two  = PlayingCard(suit: CardSuit.spades, value: CardValue.two);
      final top  = PlayingCard(suit: CardSuit.hearts, value: CardValue.ten);

      bloc.emit(bloc.state.copyWith(
        discardPile: [top],
        players: [
          bloc.state.players[0].copyWith(hand: [two]),
          bloc.state.players[1],
        ],
        currentPlayerIndex: 0,
      ));

      bloc.add(PlayCard(playerId: bloc.state.players[0].id, cards: [two]));
      await Future.delayed(Duration.zero);

      expect(bloc.state.discardPile.last, equals(two));
      expect(bloc.state.currentPlayerIndex, equals(1));
    });


  });
}
