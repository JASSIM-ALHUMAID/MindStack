import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/quiz.dart';
import 'package:mindstack/application/review.dart';
import 'package:mindstack/application/tab.dart';
import 'package:mindstack/presentation/screens/quiz_screen.dart';

import '../support/container.dart';
import '../support/pump.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _withCards(WidgetTester tester, int count) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = makeContainer(
    overrides: [quizRandomProvider.overrideWithValue(Random(1))],
  );
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  final deck = await library.createDeck(courseId: course, title: 'Deck');
  for (var i = 1; i <= count; i++) {
    await container
        .read(cardCommandsProvider)
        .addCard(deckId: deck, question: 'Q$i', answer: 'A$i');
  }
  return container;
}

void main() {
  testWidgets('fewer than 4 cards shows the empty state', (tester) async {
    final container = await _withCards(tester, 3);

    await pumpInApp(tester, container, const QuizScreen());
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Add at least 4 cards to start a quiz'), findsOneWidget);

    await tester.tap(find.text('Go to Library'));
    expect(container.read(tabIndexProvider), 1);
  });

  testWidgets('a missed question is listed and Review weak cards studies it', (
    tester,
  ) async {
    final container = await _withCards(tester, 4);

    await pumpInApp(tester, container, const QuizScreen());
    await _settle(tester);

    final quiz = container.read(quizProvider).requireValue;
    expect(find.text('QUESTION 1 OF ${quiz.questions.length}'), findsOneWidget);

    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      // Miss the first question, answer the rest correctly.
      final pick = i == 0 ? (q.correctIndex + 1) % 4 : q.correctIndex;
      await tester.tap(find.text(q.options[pick]));
      await _settle(tester);
      expect(find.text('WHY'), findsOneWidget);
      await tester.tap(find.text('Next question'));
      await _settle(tester);
    }

    final missed = quiz.questions.first;
    expect(find.text('Quiz complete'), findsOneWidget);
    expect(find.text('1 WEAK CARD'), findsOneWidget);
    expect(find.text(missed.prompt), findsOneWidget);
    expect(find.textContaining('due in your next review'), findsOneWidget);

    await tester.tap(find.text('REVIEW WEAK CARDS'));
    await _settle(tester);

    expect(container.read(tabIndexProvider), 2);
    expect(container.read(reviewProvider).requireValue.cardIds, [missed.id]);
  });

  testWidgets('with no misses, Review weak cards is hidden', (tester) async {
    final container = await _withCards(tester, 4);

    await pumpInApp(tester, container, const QuizScreen());
    await _settle(tester);

    final quiz = container.read(quizProvider).requireValue;
    for (final q in quiz.questions) {
      await tester.tap(find.text(q.options[q.correctIndex]));
      await _settle(tester);
      await tester.tap(find.text('Next question'));
      await _settle(tester);
    }

    expect(find.text('Quiz complete'), findsOneWidget);
    expect(find.text('No missed questions. Nice work.'), findsOneWidget);
    expect(find.text('REVIEW WEAK CARDS'), findsNothing);
  });
}
