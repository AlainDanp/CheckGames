import 'package:flutter_test/flutter_test.dart';

import 'package:checkgame/main.dart';
import 'mock_repository.dart';

void main() {
  testWidgets('App starts with GamePage', (WidgetTester tester) async {
    final mockRepo = MockRepository();
    await mockRepo.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(repository: mockRepo));

    // Verify that the app starts
    expect(find.text('Démarrer'), findsOneWidget);
  });
}
