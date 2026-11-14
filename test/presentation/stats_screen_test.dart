import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/review.dart';
import 'package:mindstack/application/tab.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/presentation/screens/stats_screen.dart';

import '../support/container.dart';
import '../support/fakes.dart';
import '../support/pump.dart';

final _now = DateTime(2026, 11, 4, 12);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// A container with one deck of [count] cards Q1..Q[count]; returns it and
/// the card ids.
Future<(ProviderContainer, List<String>)> _setUp(
  WidgetTester tester,
  int count,
) async {
  // Tall viewport: the Stats ListView only builds what fits on screen.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = makeContainer(clock: FixedClock(_now));
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  final deck = await library.createDeck(courseId: course, title: 'Deck');
  final cards = container.read(cardCommandsProvider);
  final ids = [
    for (var i = 1; i <= count; i++)
      await cards.addCard(deckId: deck, question: 'Q$i', answer: 'A$i'),
  ];
  return (container, ids);
}

void main() {
  testWidgets('with no reviews, streak and weakest cards show empty states', (
    tester,
  ) async {
    final (container, _) = await _setUp(tester, 2);

    await pumpInApp(tester, container, const StatsScreen());
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.text('No reviews yet. Rate a card in Review to start a streak.'),
      findsOneWidget,
    );
    expect(find.text('BEST: 0 DAYS'), findsOneWidget);
    expect(
      find.text('No reviews yet. Cards you review show here, weakest first.'),
      findsOneWidget,
    );
    expect(find.textContaining('Drill'), findsNothing);
    expect(find.textContaining('SAMPLE DATA'), findsNothing);
  });

  testWidgets('a review today shows streak 1 and drills the reviewed card', (
    tester,
  ) async {
    final (container, ids) = await _setUp(tester, 2);
    await container.read(cardCommandsProvider).rateCard(ids[1], Rating.again);

    await pumpInApp(tester, container, const StatsScreen());
    await _settle(tester);

    expect(find.text('1'), findsWidgets);
    expect(find.text(' DAY'), findsOneWidget);
    expect(find.text('BEST: 1 DAY'), findsOneWidget);
    expect(find.text('1 STUDY DAYS IN THE LAST 28'), findsOneWidget);
    // Only the reviewed card is listed, not the never-reviewed Q1.
    expect(find.text('Q2'), findsOneWidget);
    expect(find.text('Q1'), findsNothing);

    await tester.tap(find.text('Drill 1 weak card now'));
    await _settle(tester);

    expect(container.read(tabIndexProvider), 2);
    expect(container.read(reviewProvider).requireValue.cardIds, [ids[1]]);
  });

  testWidgets('planner shows an inline message for a bad total, then a plan', (
    tester,
  ) async {
    final (container, _) = await _setUp(tester, 0);

    await pumpInApp(tester, container, const StatsScreen());
    await _settle(tester);

    final total = find.byType(TextField);
    for (final bad in ['0', '-3', 'abc', '2.5']) {
      await tester.enterText(total, bad);
      await tester.tap(find.text('Plan'));
      await tester.pump();
      expect(
        find.text('Enter a whole number of cards, 1 or more.'),
        findsOneWidget,
        reason: 'total "$bad"',
      );
      expect(find.text('PLAN'), findsNothing);
    }

    await tester.enterText(total, '42');
    await tester.tap(find.text('Plan'));
    await tester.pump();

    // The default exam date is 21 days ahead: 42 / 21 = 2 cards a day.
    expect(
      find.text('Enter a whole number of cards, 1 or more.'),
      findsNothing,
    );
    expect(
      find.text(
        '2 cards per day to cover all 42 cards. Review the weakest ones first.',
      ),
      findsOneWidget,
    );
    expect(find.text('21 DAYS'), findsOneWidget);
  });
}
