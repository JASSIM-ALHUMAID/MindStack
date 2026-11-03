import 'package:flutter/widgets.dart';
import 'package:mindstack/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app opens on the Library tab and can switch tabs', (tester) async {
    // Tall viewport: the Stats screen is a lazy ListView, so its planner card
    // is only built when it fits on screen.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: MindStackApp()));
    await tester.pumpAndSettle();

    expect(find.text('COURSES AND DECKS'), findsOneWidget);

    await tester.tap(find.text('STATS').last);
    await tester.pumpAndSettle();
    expect(find.text('Exam quota planner'), findsOneWidget);
  });
}
