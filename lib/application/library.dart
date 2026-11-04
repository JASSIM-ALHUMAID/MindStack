import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../domain/failures.dart';
import '../domain/models/course.dart';
import '../domain/models/deck.dart';
import 'core_providers.dart';
import 'validation.dart';

/// Live list of courses, ordered by exam date then title.
final coursesProvider = StreamProvider<List<Course>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchCourses(),
);

/// Live list of decks, ordered by title.
final decksProvider = StreamProvider<List<Deck>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchDecks(),
);

/// One deck by id, derived from [decksProvider]. Data is null when the deck
/// does not exist (for example, it was just deleted).
final deckProvider = Provider.autoDispose.family<AsyncValue<Deck?>, String>(
  (ref, id) => ref.watch(decksProvider).whenData((decks) {
    for (final deck in decks) {
      if (deck.id == id) return deck;
    }
    return null;
  }),
);

/// Writes to courses and decks.
final libraryCommandsProvider = Provider<LibraryCommands>(LibraryCommands.new);

/// Validated writes to courses and decks.
final class LibraryCommands {
  /// Creates the commands reading its dependencies from [_ref] at call time.
  const LibraryCommands(this._ref);

  final Ref _ref;

  /// Creates a course and returns its id. [title] is trimmed and
  /// [examDate] is reduced to its calendar date.
  ///
  /// Throws [InvalidInput] for a blank title and [StorageFailure] if the
  /// write fails.
  Future<String> createCourse({
    required String title,
    required DateTime examDate,
  }) async {
    final name = requireText(
      title,
      field: 'title',
      reason: 'Enter a course name.',
    );
    final id = _ref.read(idGeneratorProvider).newId();
    await _ref
        .read(libraryRepositoryProvider)
        .insertCourse(
          Course(id: id, title: name, examDate: dateOnly(examDate)),
        );
    return id;
  }

  /// Creates a deck in [courseId] and returns its id. [title] is trimmed.
  ///
  /// Throws [InvalidInput] for a blank title, [NotFound] if the course does
  /// not exist, [Conflict] (duplicate title) if the course already has a deck
  /// with that name, and [StorageFailure] if the write fails.
  Future<String> createDeck({
    required String courseId,
    required String title,
  }) async {
    final name = requireText(
      title,
      field: 'title',
      reason: 'Enter a deck name.',
    );
    final id = _ref.read(idGeneratorProvider).newId();
    await _ref
        .read(libraryRepositoryProvider)
        .insertDeck(Deck(id: id, courseId: courseId, title: name));
    return id;
  }

  /// Deletes deck [id] together with its cards and review logs.
  ///
  /// Throws [NotFound] if the deck does not exist and [StorageFailure] if the
  /// write fails.
  Future<void> deleteDeck(String id) =>
      _ref.read(libraryRepositoryProvider).deleteDeck(id);

  /// Moves every card of [fromId] into [toId], then deletes [fromId], in one
  /// transaction. Returns the number of cards moved.
  ///
  /// Throws [InvalidInput] when both ids are equal, [NotFound] if either
  /// deck does not exist, and [StorageFailure] if a write fails. Nothing is
  /// changed on failure.
  Future<int> mergeDecks({required String fromId, required String toId}) async {
    if (fromId == toId) {
      throw const InvalidInput(
        field: 'toId',
        reason: 'Choose a different deck to merge into.',
      );
    }
    return await _ref.read(transactionRunnerProvider).run(() async {
      final moved = await _ref
          .read(cardRepositoryProvider)
          .moveToDeck(fromDeckId: fromId, toDeckId: toId);
      await _ref.read(libraryRepositoryProvider).deleteDeck(fromId);
      return moved;
    });
  }
}
