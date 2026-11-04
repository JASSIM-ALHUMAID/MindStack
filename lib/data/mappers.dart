import 'package:drift/drift.dart';

import '../domain/models/course.dart';
import '../domain/models/deck.dart';
import '../domain/models/draft_card.dart';
import '../domain/models/flashcard.dart';
import '../domain/models/review_log.dart';
import 'database/app_database.dart';

// Instants are written as UTC and returned in local time.

extension CourseToCompanion on Course {
  CoursesCompanion toCompanion() =>
      CoursesCompanion.insert(id: id, title: title, examDate: examDate);
}

extension CourseRowToModel on CourseRow {
  Course toModel() => Course(id: id, title: title, examDate: examDate);
}

extension DeckToCompanion on Deck {
  DecksCompanion toCompanion() =>
      DecksCompanion.insert(id: id, courseId: courseId, title: title);
}

extension DeckRowToModel on DeckRow {
  Deck toModel() => Deck(id: id, courseId: courseId, title: title);
}

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

extension ReviewLogToCompanion on ReviewLog {
  ReviewLogsCompanion toCompanion() => ReviewLogsCompanion.insert(
    id: id,
    cardId: cardId,
    reviewedAt: reviewedAt.toUtc(),
    rating: rating,
    elapsedMs: elapsedMs,
  );
}

extension ReviewLogRowToModel on ReviewLogRow {
  ReviewLog toModel() => ReviewLog(
    id: id,
    cardId: cardId,
    reviewedAt: reviewedAt.toLocal(),
    rating: rating,
    elapsedMs: elapsedMs,
  );
}
