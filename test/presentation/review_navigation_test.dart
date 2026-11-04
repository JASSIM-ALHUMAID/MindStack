import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/review.dart';
import 'package:mindstack/application/tab.dart';
import 'package:mindstack/presentation/screens/app_shell.dart';

import '../support/container.dart';
import '../support/pump.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entering Review from navigation refreshes the due queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = makeContainer();
    final library = c.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deck = await library.createDeck(courseId: course, title: 'Deck');
    await pumpInApp(tester, c, const AppShell());
    await _settle(tester);
    expect(c.read(reviewProvider).requireValue.cardIds, isEmpty);

    final added = await tester.runAsync(
      () => c
          .read(cardCommandsProvider)
          .addCard(
            deckId: deck,
            question: 'Added after launch',
            answer: 'Answer',
          ),
    );
    await tester.tap(find.text('REVIEW').last);
    await _settle(tester);

    expect(c.read(reviewProvider).requireValue.cardIds, [added]);
    expect(find.text('Added after launch'), findsOneWidget);
  });

  testWidgets('a programmatic tab switch preserves selected practice cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = makeContainer();
    final library = c.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deck = await library.createDeck(courseId: course, title: 'Deck');
    final commands = c.read(cardCommandsProvider);
    final a = await commands.addCard(
      deckId: deck,
      question: 'A',
      answer: 'Answer A',
    );
    final b = await commands.addCard(
      deckId: deck,
      question: 'B',
      answer: 'Answer B',
    );
    await pumpInApp(tester, c, const AppShell());
    await _settle(tester);

    await tester.runAsync(
      () => c.read(reviewProvider.notifier).start(cardIds: [b]),
    );
    c.read(tabIndexProvider.notifier).set(2);
    await _settle(tester);

    final queue = c.read(reviewProvider).requireValue.cardIds;
    expect(queue, [b]);
    expect(queue, isNot(contains(a)));
    expect(find.text('B'), findsOneWidget);
  });
}
