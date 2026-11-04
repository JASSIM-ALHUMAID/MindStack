// The self-referencing getters inside `check(...)` are drift's column DSL.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../domain/enums.dart';
import 'converters.dart';

// Constraints live in the store so no code path can bypass them. Text columns
// are checked with `trim()` so whitespace-only values are rejected too.

/// A course with its exam date. Rows are read as `CourseRow`.
@DataClassName('CourseRow')
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get title =>
      text().check(title.trim().length.isBiggerThanValue(0))();
  TextColumn get examDate => text().map(const DateOnlyConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// A deck inside a course. Deleting the course deletes its decks.
@DataClassName('DeckRow')
@TableIndex(name: 'decks_course_id', columns: {#courseId})
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get courseId =>
      text().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get title =>
      text().check(title.trim().length.isBiggerThanValue(0))();

  @override
  Set<Column> get primaryKey => {id};

  /// Deck titles are unique per course regardless of letter case.
  @override
  List<String> get customConstraints => [
    'UNIQUE (course_id, title COLLATE NOCASE)',
  ];
}

/// A flashcard with its spaced-repetition state. Deleting the deck deletes
/// its cards.
@DataClassName('FlashcardRow')
@TableIndex(name: 'flashcards_deck_id', columns: {#deckId})
// Note: drift compares text DateTimes through julianday(), so SQLite cannot
// use this index for `CardRepository.due`. Kept for plain dueAt lookups and
// in case that query changes.
@TableIndex(name: 'flashcards_due_at', columns: {#dueAt})
class Flashcards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId =>
      text().references(Decks, #id, onDelete: KeyAction.cascade)();
  TextColumn get question =>
      text().check(question.trim().length.isBiggerThanValue(0))();
  TextColumn get answer =>
      text().check(answer.trim().length.isBiggerThanValue(0))();
  TextColumn get source => textEnum<CardSource>()();
  TextColumn get sourceRef => text().nullable()();
  IntColumn get intervalDays => integer()
      .withDefault(const Constant(0))
      .check(intervalDays.isBiggerOrEqualValue(0))();
  RealColumn get ease => real()
      .withDefault(const Constant(2.5))
      .check(ease.isBiggerOrEqualValue(1.3))();
  IntColumn get repetitions => integer()
      .withDefault(const Constant(0))
      .check(repetitions.isBiggerOrEqualValue(0))();
  DateTimeColumn get dueAt => dateTime()();
  RealColumn get mastery => real()
      .withDefault(const Constant(0))
      .check(mastery.isBetweenValues(0, 1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// An unsaved OCR draft card, held until the user saves or clears it.
@DataClassName('DraftCardRow')
class DraftCards extends Table {
  TextColumn get id => text()();
  TextColumn get source => textEnum<CardSource>()();
  TextColumn get sourceRef => text()();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  BoolColumn get selected => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One rating of a card. Deleting the card deletes its log entries.
@DataClassName('ReviewLogRow')
@TableIndex(name: 'review_logs_card_id', columns: {#cardId})
@TableIndex(name: 'review_logs_reviewed_at', columns: {#reviewedAt})
class ReviewLogs extends Table {
  TextColumn get id => text()();
  TextColumn get cardId =>
      text().references(Flashcards, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get reviewedAt => dateTime()();
  TextColumn get rating => textEnum<Rating>()();
  IntColumn get elapsedMs =>
      integer().check(elapsedMs.isBiggerOrEqualValue(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key/value bookkeeping, such as the `seeded` flag.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
