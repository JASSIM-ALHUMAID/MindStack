import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/data/repositories/drift_library_repository.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/repositories.dart';

import '../support/container.dart';

/// Delegates to [_inner] except that [deleteDeck] always fails.
final class _FailingDeleteLibrary implements LibraryRepository {
  _FailingDeleteLibrary(this._inner);

  final LibraryRepository _inner;

  @override
  Stream<List<Course>> watchCourses() => _inner.watchCourses();

  @override
  Stream<List<Deck>> watchDecks() => _inner.watchDecks();

  @override
  Future<void> insertCourse(Course course) => _inner.insertCourse(course);

  @override
  Future<void> insertDeck(Deck deck) => _inner.insertDeck(deck);

  @override
  Future<void> deleteDeck(String id) async =>
      throw StorageFailure(StateError('disk full'), StackTrace.current);
}

final _exam = DateTime(2026, 12, 1, 9, 30);

void main() {
  test('createCourse trims the title and returns the new id', () async {
    final container = makeContainer();
    final commands = container.read(libraryCommandsProvider);

    final id = await commands.createCourse(
      title: '  Algorithms  ',
      examDate: _exam,
    );

    expect(id, 'id-1');
    final courses = await container.read(coursesProvider.future);
    expect(courses, [
      Course(id: 'id-1', title: 'Algorithms', examDate: DateTime(2026, 12, 1)),
    ]);
  });

  test(
    'createCourse with blank title throws InvalidInput and writes nothing',
    () async {
      final container = makeContainer();
      final commands = container.read(libraryCommandsProvider);

      await expectLater(
        commands.createCourse(title: '   ', examDate: _exam),
        throwsA(
          isA<InvalidInput>().having(
            (e) => e.userMessage,
            'userMessage',
            'Enter a course name.',
          ),
        ),
      );
      expect(await container.read(coursesProvider.future), isEmpty);
    },
  );

  test('createDeck with blank title throws InvalidInput', () async {
    final container = makeContainer();
    final course = await container
        .read(libraryCommandsProvider)
        .createCourse(title: 'C', examDate: _exam);

    await expectLater(
      container
          .read(libraryCommandsProvider)
          .createDeck(courseId: course, title: ' '),
      throwsA(
        isA<InvalidInput>().having(
          (e) => e.userMessage,
          'userMessage',
          'Enter a deck name.',
        ),
      ),
    );
  });

  test(
    'createDeck duplicate title surfaces Conflict(duplicateTitle)',
    () async {
      final container = makeContainer();
      final commands = container.read(libraryCommandsProvider);
      final course = await commands.createCourse(title: 'C', examDate: _exam);
      await commands.createDeck(courseId: course, title: 'Graphs');

      await expectLater(
        commands.createDeck(courseId: course, title: ' graphs '),
        throwsA(
          isA<Conflict>().having(
            (e) => e.kind,
            'kind',
            ConflictKind.duplicateTitle,
          ),
        ),
      );
    },
  );

  test('deckProvider resolves a deck and null once it is deleted', () async {
    final container = makeContainer();
    final commands = container.read(libraryCommandsProvider);
    final course = await commands.createCourse(title: 'C', examDate: _exam);
    final deck = await commands.createDeck(courseId: course, title: 'Graphs');
    container.listen(decksProvider, (_, _) {});
    await container.read(decksProvider.future);

    expect(container.read(deckProvider(deck)).value?.title, 'Graphs');

    await commands.deleteDeck(deck);
    await container.pump();
    expect(container.read(deckProvider(deck)).value, isNull);
  });

  group('mergeDecks', () {
    Future<({String from, String to})> arrange(ProviderContainer c) async {
      final library = c.read(libraryCommandsProvider);
      final cards = c.read(cardCommandsProvider);
      final course = await library.createCourse(title: 'C', examDate: _exam);
      final from = await library.createDeck(courseId: course, title: 'From');
      final to = await library.createDeck(courseId: course, title: 'To');
      await cards.addCard(deckId: from, question: 'q1', answer: 'a1');
      await cards.addCard(deckId: from, question: 'q2', answer: 'a2');
      await cards.addCard(deckId: to, question: 'q3', answer: 'a3');
      return (from: from, to: to);
    }

    test('moves cards and removes the source in one transaction', () async {
      final container = makeContainer();
      final decks = await arrange(container);

      final moved = await container
          .read(libraryCommandsProvider)
          .mergeDecks(fromId: decks.from, toId: decks.to);

      expect(moved, 2);
      expect(
        await container.read(deckCardsProvider(decks.to).future),
        hasLength(3),
      );
      final remaining = await container.read(decksProvider.future);
      expect([for (final d in remaining) d.id], [decks.to]);
    });

    test('into itself throws InvalidInput', () async {
      final container = makeContainer();
      final decks = await arrange(container);

      await expectLater(
        container
            .read(libraryCommandsProvider)
            .mergeDecks(fromId: decks.from, toId: decks.from),
        throwsA(
          isA<InvalidInput>().having(
            (e) => e.userMessage,
            'userMessage',
            'Choose a different deck to merge into.',
          ),
        ),
      );
    });

    test('rolls back when deleting the source fails', () async {
      final container = makeContainer(
        overrides: [
          libraryRepositoryProvider.overrideWith(
            (ref) => _FailingDeleteLibrary(
              DriftLibraryRepository(ref.watch(databaseProvider)),
            ),
          ),
        ],
      );
      final decks = await arrange(container);

      await expectLater(
        container
            .read(libraryCommandsProvider)
            .mergeDecks(fromId: decks.from, toId: decks.to),
        throwsA(isA<StorageFailure>()),
      );

      expect(
        await container.read(deckCardsProvider(decks.from).future),
        hasLength(2),
      );
      expect(
        await container.read(deckCardsProvider(decks.to).future),
        hasLength(1),
      );
    });
  });
}
