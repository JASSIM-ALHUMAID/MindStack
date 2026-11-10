import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/services.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/data/repositories/drift_library_repository.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/repositories.dart';
import 'package:mindstack/presentation/screens/deck_editor_screen.dart';

import '../support/container.dart';
import '../support/fakes.dart';
import '../support/pump.dart';

/// A [LibraryRepository] whose deck stream fails on first listen.
final class _FailingDecks implements LibraryRepository {
  _FailingDecks(this._inner);

  final LibraryRepository _inner;

  @override
  Stream<List<Deck>> watchDecks() => Stream.error(
    StorageFailure(StateError('disk is on fire'), StackTrace.current),
  );

  @override
  Stream<List<Course>> watchCourses() => _inner.watchCourses();

  @override
  Future<Deck> deckById(String id) => _inner.deckById(id);

  @override
  Future<void> insertCourse(Course course) => _inner.insertCourse(course);

  @override
  Future<void> insertDeck(Deck deck) => _inner.insertDeck(deck);

  @override
  Future<void> deleteDeck(String id) => _inner.deleteDeck(id);
}

void main() {
  testWidgets('deck editor shows the error copy when loading fails', (
    tester,
  ) async {
    final logger = RecordingLogger();
    final container = makeContainer(
      overrides: [
        loggerProvider.overrideWithValue(logger),
        libraryRepositoryProvider.overrideWith(
          (ref) => _FailingDecks(
            DriftLibraryRepository(ref.watch(databaseProvider)),
          ),
        ),
      ],
    );

    await pumpInApp(tester, container, const DeckEditorScreen(deckId: 'x'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text("Couldn't load this. Please try again."), findsOneWidget);
    expect(find.textContaining('disk is on fire'), findsNothing);
    expect(logger.errors, hasLength(1));
  });

  testWidgets('deck editor shows not-found state when the deck is deleted', (
    tester,
  ) async {
    final container = makeContainer();
    await container.read(appStartupProvider.future);
    final library = container.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deckId = await library.createDeck(courseId: course, title: 'Doomed');
    await container
        .read(cardCommandsProvider)
        .addCard(deckId: deckId, question: 'Q1', answer: 'A1');

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('library home')),
        ),
        GoRoute(
          path: '/deck/:id',
          builder: (_, state) =>
              DeckEditorScreen(deckId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpRouter(tester, container, router);
    router.push<void>('/deck/$deckId').ignore();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(find.text('Doomed'), findsOneWidget);
    expect(find.text('Q1'), findsOneWidget);

    await library.deleteDeck(deckId);
    await tester.pump();
    await tester.pump();

    expect(find.text('This deck no longer exists.'), findsOneWidget);
    expect(find.text('Q1'), findsNothing);

    await tester.tap(find.text('Back to Library'));
    await tester.pumpAndSettle();

    expect(find.text('library home'), findsOneWidget);
  });

  testWidgets('deleting the last card asks first, then shows the empty state '
      'and Undo brings it back', (tester) async {
    final container = makeContainer();
    final deckId = await _deckWithOneCard(container);

    await pumpInApp(tester, container, DeckEditorScreen(deckId: deckId));
    await tester.pump();
    await tester.pump();
    expect(find.text('Q1'), findsOneWidget);

    // Cancel keeps the card.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete card?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Q1'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _settleDb(tester);

    expect(find.text('Q1'), findsNothing);
    expect(find.text('Card deleted'), findsOneWidget);
    expect(find.text('No cards yet. Tap + Card to add one.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settleDb(tester);

    expect(find.text('Q1'), findsOneWidget);
    expect(find.text('No cards yet. Tap + Card to add one.'), findsNothing);
  });

  testWidgets('edit sheet rejects an empty question and does not save', (
    tester,
  ) async {
    final container = makeContainer();
    final deckId = await _deckWithOneCard(container);

    await pumpInApp(tester, container, DeckEditorScreen(deckId: deckId));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit card'), findsOneWidget);

    final question = find.widgetWithText(TextFormField, 'Question');
    await tester.enterText(question, '   ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a question'), findsOneWidget);
    expect(find.text('Edit card'), findsOneWidget);
    final stored = await _cards(tester, container, deckId);
    expect(stored.single.question, 'Q1');
  });

  testWidgets('edit sheet saves new text and keeps the schedule', (
    tester,
  ) async {
    final container = makeContainer();
    final deckId = await _deckWithOneCard(container);
    final before = (await _cards(tester, container, deckId)).single;

    await pumpInApp(tester, container, DeckEditorScreen(deckId: deckId));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Answer'),
      'A1 revised',
    );
    await tester.tap(find.text('Save changes'));
    await _settleDb(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Edit card'), findsNothing);
    expect(find.text('A1 revised'), findsOneWidget);
    final after = (await _cards(tester, container, deckId)).single;
    expect(after, before.copyWith(answer: 'A1 revised'));
  });
}

/// Creates a course with one deck holding card Q1/A1; returns the deck id.
Future<String> _deckWithOneCard(ProviderContainer container) async {
  await container.read(appStartupProvider.future);
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  final deckId = await library.createDeck(courseId: course, title: 'Deck');
  await container
      .read(cardCommandsProvider)
      .addCard(deckId: deckId, question: 'Q1', answer: 'A1');
  return deckId;
}

/// Lets a database write finish and its stream update reach the widgets.
Future<void> _settleDb(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The stored cards of [deckId], read straight from the repository (outside
/// the test's fake clock) so no auto-disposed provider value is reused.
Future<List<Flashcard>> _cards(
  WidgetTester tester,
  ProviderContainer container,
  String deckId,
) async => (await tester.runAsync(
  () => container.read(cardRepositoryProvider).watchByDeck(deckId).first,
))!;
