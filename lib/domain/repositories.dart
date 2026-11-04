import 'models/course.dart';
import 'models/deck.dart';
import 'models/deck_stats.dart';
import 'models/draft_card.dart';
import 'models/flashcard.dart';
import 'models/review_log.dart';

/// Runs several repository calls as one atomic unit.
abstract interface class TransactionRunner {
  /// Runs [action] atomically. Repository calls inside join the transaction.
  Future<T> run<T>(Future<T> Function() action);
}

/// Courses and the decks inside them. Writes throw only `AppFailure`.
abstract interface class LibraryRepository {
  /// Courses ordered by exam date, then title.
  Stream<List<Course>> watchCourses();

  /// Decks ordered by title.
  Stream<List<Deck>> watchDecks();

  /// The deck with [id]. Throws `NotFound` if it does not exist.
  Future<Deck> deckById(String id);

  /// Throws `Conflict` on a duplicate id.
  Future<void> insertCourse(Course course);

  /// Throws `Conflict` on a duplicate id or a duplicate title in the course.
  Future<void> insertDeck(Deck deck);

  /// Deletes a deck and, by cascade, its cards and review logs.
  /// Throws `NotFound` if the deck does not exist.
  Future<void> deleteDeck(String id);
}

/// Flashcards. Writes throw only `AppFailure`.
abstract interface class CardRepository {
  /// Every card.
  Stream<List<Flashcard>> watchAll();

  /// Cards of one deck.
  Stream<List<Flashcard>> watchByDeck(String deckId);

  /// Per-deck stats from one aggregate; empty decks are included with 0.
  Stream<Map<String, DeckStats>> watchDeckStats();

  /// Cards due at or before [now], optionally limited to [deckId].
  Future<List<Flashcard>> due({required DateTime now, String? deckId});

  /// The card with [id]. Throws `NotFound` if it does not exist.
  Future<Flashcard> byId(String id);

  /// Throws `Conflict` on a duplicate id.
  Future<void> insert(Flashcard card);

  /// Inserts all [cards] atomically.
  Future<void> insertAll(List<Flashcard> cards);

  /// Throws `NotFound` if the card does not exist.
  Future<void> update(Flashcard card);

  /// Throws `NotFound` if the card does not exist.
  Future<void> delete(String id);

  /// Moves every card of [fromDeckId] into [toDeckId] and returns the count.
  Future<int> moveToDeck({
    required String fromDeckId,
    required String toDeckId,
  });
}

/// OCR drafts awaiting the user's decision. Writes throw only `AppFailure`.
abstract interface class DraftRepository {
  /// Every draft.
  Stream<List<DraftCard>> watchAll();

  /// Drafts currently selected for saving.
  Future<List<DraftCard>> selected();

  /// Inserts all [drafts] atomically.
  Future<void> insertAll(List<DraftCard> drafts);

  /// Flips the selection of draft [id]. Throws `NotFound` if missing.
  Future<void> toggleSelected(String id);

  /// Deletes the drafts with the given [ids].
  Future<void> delete(Iterable<String> ids);

  /// Deletes every draft.
  Future<void> clear();
}

/// The log of rated reviews. Writes throw only `AppFailure`.
abstract interface class ReviewLogRepository {
  /// Every log entry.
  Stream<List<ReviewLog>> watchAll();

  /// Throws `Conflict` on a duplicate id.
  Future<void> insert(ReviewLog log);
}
