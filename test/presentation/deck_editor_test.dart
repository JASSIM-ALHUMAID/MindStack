import 'package:flutter/material.dart';
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

  testWidgets('deleting a card removes it and confirms', (tester) async {
    final container = makeContainer();
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

    await pumpInApp(tester, container, DeckEditorScreen(deckId: deckId));
    await tester.pump();
    await tester.pump();
    expect(find.text('Q1'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Q1'), findsNothing);
    expect(find.text('Card deleted'), findsOneWidget);
    expect(find.text('No cards yet. Tap + Card to add one.'), findsOneWidget);
  });
}
