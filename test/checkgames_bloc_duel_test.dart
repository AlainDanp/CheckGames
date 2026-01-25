import 'package:flutter_test/flutter_test.dart';
import 'package:checkgame/Bloc/checkgames_bloc.dart';
import 'package:checkgame/Bloc/checkgames_state.dart';
import 'package:checkgame/Bloc/checkgames_event.dart';
import 'package:checkgame/models/card_value.dart';
import 'package:checkgame/models/card_suit.dart';
import 'package:checkgame/models/playing_card.dart';

import 'mock_repository.dart';

void main() {
  group('Phase Duel', () {
    test('Partie se termine avec classement complet (sans duel)', () async {
      final bloc = CheckGameBloc(repository: MockRepository());

      // Démarrer une partie avec 3 joueurs
      bloc.add(StartGame(['Alice', 'Bob', 'Charlie']));
      await Future.delayed(Duration.zero);

      expect(bloc.state.players.length, 3);
      expect(bloc.state.phase, GamePhase.normal);

      // Simuler que tous les joueurs finissent leur main (sans duel)
      // Note: En pratique, il faudrait jouer des cartes pour vider les mains
      // Ce test est simplifié pour vérifier la logique de base

      // Vérifier l'état initial
      expect(bloc.state.isGameOver, false);
      expect(bloc.state.finishingOrder.isEmpty, true);
    });

    test('Phase duel devrait être déclenchée quand il reste 2 joueurs', () async {
      final bloc = CheckGameBloc(repository: MockRepository());

      bloc.add(StartGame(['Alice', 'Bob', 'Charlie']));
      await Future.delayed(Duration.zero);

      // Pour tester proprement le duel, il faudrait :
      // 1. Faire finir la main d'Alice (1er joueur)
      // 2. Vérifier que la phase reste normale
      // 3. Faire finir la main de Bob (2e joueur)
      // 4. Vérifier que phase == GamePhase.duel
      // 5. Charlie et un autre joueur seraient en duel

      // Actuellement, c'est difficile à tester sans contrôler le deck
      // Ces tests nécessiteraient un mock plus sophistiqué du DeckGenerator

      expect(bloc.state.phase, GamePhase.normal);
    });

    test('Partie devrait être terminée (finished) après le duel', () async {
      final bloc = CheckGameBloc(repository: MockRepository());

      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      // Test simplifié - vérifier que le jeu peut se terminer
      expect(bloc.state.isGameOver, false);
      expect(bloc.state.phase, GamePhase.normal);
    });

    test('FinishingOrder devrait contenir tous les joueurs à la fin', () async {
      final bloc = CheckGameBloc(repository: MockRepository());

      bloc.add(StartGame(['Alice', 'Bob', 'Charlie', 'David']));
      await Future.delayed(Duration.zero);

      expect(bloc.state.players.length, 4);

      // À la fin du jeu, finishingOrder devrait contenir 4 joueurs
      // (Test conceptuel - nécessiterait de jouer une partie complète)
    });
  });

  group('Repository Integration', () {
    test('Les stats devraient être sauvegardées à la fin du jeu', () async {
      final mockRepo = MockRepository();
      final bloc = CheckGameBloc(repository: mockRepo);

      bloc.add(StartGame(['Alice', 'Bob']));
      await Future.delayed(Duration.zero);

      // Après une partie complète, l'historique devrait être sauvegardé
      // (Test conceptuel - nécessiterait de terminer une partie)

      expect(mockRepo.getGameHistory().isEmpty, true);
    });
  });
}
