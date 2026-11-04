import 'package:drift/drift.dart';

import '../domain/models/course.dart';
import '../domain/models/deck.dart';
import '../domain/models/draft_card.dart';
import '../domain/models/flashcard.dart';
import '../domain/models/review_log.dart';
import 'database/app_database.dart';

// Instants are written as UTC and returned in local time.

/// Converts a [Course] into an insert companion.
extension CourseToCompanion on Course {
  CoursesCompanion toCompanion() =>
      CoursesCompanion.insert(id: id, title: title, examDate: examDate);
}

/// Converts a stored course row into a [Course].
extension CourseRowToModel on CourseRow {
  Course toModel() => Course(id: id, title: title, examDate: examDate);
}

/// Converts a [Deck] into an insert companion.
extension DeckToCompanion on Deck {
  DecksCompanion toCompanion() =>
      DecksCompanion.insert(id: id, courseId: courseId, title: title);
}

/// Converts a stored deck row into a [Deck].
extension DeckRowToModel on DeckRow {
  Deck toModel() => Deck(id: id, courseId: courseId, title: title);
}

/// Converts a [Flashcard] into an insert companion (instants as UTC).
extension FlashcardToCompanion on Flashcard {
  FlashcardsCompanion toCompanion() => FlashcardsCompanion.insert(
    id: id,
    deckId: deckId,
    question: question,
    answer: answer,
    source: source,
    sourceRef: Value(sourceRef),
    intervalDays: Value(intervalDays),
    ease: Value(ease),
    repetitions: Value(repetitions),
    dueAt: dueAt.toUtc(),
    mastery: Value(mastery),
  );
}

/// Converts a stored card row into a [Flashcard] (instants in local time).
extension FlashcardRowToModel on FlashcardRow {
  Flashcard toModel() => Flashcard(
    id: id,
    deckId: deckId,
    question: question,
    answer: answer,
    source: source,
    sourceRef: sourceRef,
    intervalDays: intervalDays,
    ease: ease,
    repetitions: repetitions,
    dueAt: dueAt.toLocal(),
    mastery: mastery,
  );
}

/// Converts a [DraftCard] into an insert companion.
extension DraftCardToCompanion on DraftCard {
  DraftCardsCompanion toCompanion() => DraftCardsCompanion.insert(
    id: id,
    source: source,
    sourceRef: sourceRef,
    question: question,
    answer: answer,
    selected: Value(selected),
  );
}

/// Converts a stored draft row into a [DraftCard].
extension DraftCardRowToModel on DraftCardRow {
  DraftCard toModel() => DraftCard(
    id: id,
    source: source,
    sourceRef: sourceRef,
    question: question,
    answer: answer,
    selected: selected,
  );
}

/// Converts a [ReviewLog] into an insert companion (instants as UTC).
extension ReviewLogToCompanion on ReviewLog {
  ReviewLogsCompanion toCompanion() => ReviewLogsCompanion.insert(
    id: id,
    cardId: cardId,
    reviewedAt: reviewedAt.toUtc(),
    rating: rating,
    elapsedMs: elapsedMs,
  );
}

/// Converts a stored log row into a [ReviewLog] (instants in local time).
extension ReviewLogRowToModel on ReviewLogRow {
  ReviewLog toModel() => ReviewLog(
    id: id,
    cardId: cardId,
    reviewedAt: reviewedAt.toLocal(),
    rating: rating,
    elapsedMs: elapsedMs,
  );
}
