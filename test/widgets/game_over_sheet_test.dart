import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checkgame/view/widgets/game_over_sheet.dart';
import 'package:checkgame/models/player_card.dart';

void main() {
  testWidgets('GameOverSheet affiche le classement complet', (tester) async {
    final players = [
      Player(id: '1', name: 'Alice', hand: const []),
      Player(id: '2', name: 'Bob', hand: const []),
      Player(id: '3', name: 'Charlie', hand: const []),
    ];
    final order = ['1', '2', '3'];
    bool restartCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameOverSheet(
          finishingOrder: order,
          allPlayers: players,
          onRestart: () {
            restartCalled = true;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Vérifier le titre
    expect(find.text('Partie terminée !'), findsOneWidget);

    // Vérifier que tous les joueurs sont affichés
    expect(find.text('1. Alice'), findsOneWidget);
    expect(find.text('2. Bob'), findsOneWidget);
    expect(find.text('3. Charlie'), findsOneWidget);

    // Vérifier les boutons
    expect(find.text('Rejouer'), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);

    // Vérifier les médailles
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
    expect(find.text('🥉'), findsOneWidget);

    // Vérifier que le trophée est affiché pour le gagnant
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);

    // Tester le bouton Rejouer
    await tester.tap(find.text('Rejouer'));
    await tester.pump();
    expect(restartCalled, true);
  });

  testWidgets('GameOverSheet affiche correctement 2 joueurs', (tester) async {
    final players = [
      Player(id: '1', name: 'Alice', hand: const []),
      Player(id: '2', name: 'Bob', hand: const []),
    ];
    final order = ['1', '2'];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameOverSheet(
          finishingOrder: order,
          allPlayers: players,
          onRestart: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Partie terminée !'), findsOneWidget);
    expect(find.text('1. Alice'), findsOneWidget);
    expect(find.text('2. Bob'), findsOneWidget);
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
  });

  testWidgets('GameOverSheet affiche correctement 4 joueurs', (tester) async {
    final players = [
      Player(id: '1', name: 'Alice', hand: const []),
      Player(id: '2', name: 'Bob', hand: const []),
      Player(id: '3', name: 'Charlie', hand: const []),
      Player(id: '4', name: 'David', hand: const []),
    ];
    final order = ['2', '1', '4', '3'];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GameOverSheet(
          finishingOrder: order,
          allPlayers: players,
          onRestart: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Partie terminée !'), findsOneWidget);

    // Vérifier l'ordre du classement
    expect(find.text('1. Bob'), findsOneWidget);
    expect(find.text('2. Alice'), findsOneWidget);
    expect(find.text('3. David'), findsOneWidget);
    expect(find.text('4. Charlie'), findsOneWidget);

    // Vérifier les médailles
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
    expect(find.text('🥉'), findsOneWidget);
    expect(find.text('4️⃣'), findsOneWidget);
  });
}
