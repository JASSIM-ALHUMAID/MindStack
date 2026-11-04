import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/app.dart';

import '../support/container.dart';

void main() {
  testWidgets('app opens on the Library tab and can switch tabs', (
    tester,
  ) async {
    // Tall viewport: the Stats screen is a lazy ListView, so its planner card
    // is only built when it fits on screen.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = makeContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MindStackApp(),
      ),
    );
    // Startup opens and seeds the in-memory database, then the screens read it.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    expect(find.text('COURSES AND DECKS'), findsOneWidget);

    await tester.tap(find.text('STATS').last);
    await tester.pumpAndSettle();
    expect(find.text('Exam quota planner'), findsOneWidget);
  });
}
