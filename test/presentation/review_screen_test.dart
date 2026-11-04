import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/services.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/repositories.dart';
import 'package:mindstack/presentation/screens/review_screen.dart';

import '../support/container.dart';
import '../support/fakes.dart';
import '../support/pump.dart';

final class _FailingRunner implements TransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() action) =>
      Future.error(StorageFailure(StateError('disk full'), StackTrace.current));
}

void main() {
  testWidgets('review screen rating advances to the next card', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = makeContainer();
    await container.read(appStartupProvider.future);
    // Only the cards created here are due: the seeded cards are removed.
    final db = container.read(databaseProvider);
    await db.delete(db.flashcards).go();
    final library = container.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deckId = await library.createDeck(courseId: course, title: 'Deck');
    final cards = container.read(cardCommandsProvider);
    final first = await cards.addCard(
      deckId: deckId,
      question: 'First question',
      answer: 'First answer',
    );
    await cards.addCard(
      deckId: deckId,
      question: 'Second question',
      answer: 'Second answer',
    );

    await pumpInApp(tester, container, const ReviewScreen());
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('First question'), findsOneWidget);
    expect(find.text('Card 1 of 2'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('First question'));
    await tester.pump();
    expect(find.text('First answer'), findsOneWidget);

    await tester.tap(find.text('Good'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('Second question'), findsOneWidget);
    expect(find.text('First question'), findsNothing);
    expect(find.text('1 / 2 CARDS (50%)'), findsOneWidget);
    final stored = await container.read(cardRepositoryProvider).byId(first);
    expect(stored.repetitions, 1);
  });

  testWidgets('a failed rating shows the message and allows another try', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final logger = RecordingLogger();
    final container = makeContainer(
      overrides: [
        loggerProvider.overrideWithValue(logger),
        transactionRunnerProvider.overrideWithValue(_FailingRunner()),
      ],
    );
    await container.read(appStartupProvider.future);
    final db = container.read(databaseProvider);
    await db.delete(db.flashcards).go();
    final library = container.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deckId = await library.createDeck(courseId: course, title: 'Deck');
    await container
        .read(cardCommandsProvider)
        .addCard(deckId: deckId, question: 'Only question', answer: 'A');

    await pumpInApp(tester, container, const ReviewScreen());
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('Only question'));
    await tester.pump();
    await tester.tap(find.text('Good'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text("Couldn't save. Please try again."), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
    expect(find.text('Only question'), findsOneWidget);
    expect(logger.errors, hasLength(1));
    final good = tester.widget<InkWell>(
      find.ancestor(of: find.text('Good'), matching: find.byType(InkWell)),
    );
    expect(good.onTap, isNotNull, reason: 'rating can be retried');
  });

  testWidgets('a deleted front card offers Skip, which advances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = makeContainer();
    await container.read(appStartupProvider.future);
    final db = container.read(databaseProvider);
    await db.delete(db.flashcards).go();
    final library = container.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deckId = await library.createDeck(courseId: course, title: 'Deck');
    final cards = container.read(cardCommandsProvider);
    final gone = await cards.addCard(
      deckId: deckId,
      question: 'Gone question',
      answer: 'A',
    );
    await cards.addCard(deckId: deckId, question: 'Next question', answer: 'A');

    await pumpInApp(tester, container, const ReviewScreen());
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await cards.deleteCard(gone);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('This card no longer exists.'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Next question'), findsOneWidget);
    expect(find.text('This card no longer exists.'), findsNothing);
  });

  testWidgets('skipping a deleted card shows the next card with its answer '
      'hidden', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = makeContainer();
    await container.read(appStartupProvider.future);
    final db = container.read(databaseProvider);
    await db.delete(db.flashcards).go();
    final library = container.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deckId = await library.createDeck(courseId: course, title: 'Deck');
    final cards = container.read(cardCommandsProvider);
    final first = await cards.addCard(
      deckId: deckId,
      question: 'First question',
      answer: 'First answer',
    );
    await cards.addCard(
      deckId: deckId,
      question: 'Second question',
      answer: 'Second answer',
    );

    await pumpInApp(tester, container, const ReviewScreen());
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('First question'));
    await tester.pump();
    expect(find.text('First answer'), findsOneWidget);
    await cards.deleteCard(first);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Second question'), findsOneWidget);
    expect(find.text('Second answer'), findsNothing);
  });
}
