import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:mindstack/data/mappers.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/models/review_log.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../support/test_database.dart';

Course _course(String id, {String title = 'Mobile Dev'}) =>
    Course(id: id, title: title, examDate: DateTime(2026, 12, 1));

Flashcard _card(String id, String deckId, {DateTime? dueAt}) => Flashcard(
  id: id,
  deckId: deckId,
  question: 'Q',
  answer: 'A',
  source: CardSource.photo,
  dueAt: dueAt ?? DateTime(2026, 11, 4, 9),
);

Future<AppDatabase> _open() async {
  final db = openTestDatabase();
  addTearDown(db.close);
  await db.ensureOpen();
  return db;
}

Future<void> _seedDeck(AppDatabase db) async {
  await db.into(db.courses).insert(_course('c1').toCompanion());
  await db
      .into(db.decks)
      .insert(
        const Deck(id: 'd1', courseId: 'c1', title: 'Flutter').toCompanion(),
      );
}

Matcher _sqliteCode(int code) => isA<SqliteException>().having(
  (e) => e.extendedResultCode,
  'extendedResultCode',
  code,
);

void main() {
  test('foreign keys are enforced', () async {
    final db = await _open();
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.single, 1);
  });

  test('deleting a deck cascades to its cards and their review logs', () async {
    final db = await _open();
    await _seedDeck(db);
    await db.into(db.flashcards).insert(_card('k1', 'd1').toCompanion());
    await db
        .into(db.reviewLogs)
        .insert(
          ReviewLog(
            id: 'r1',
            cardId: 'k1',
            reviewedAt: DateTime(2026, 11, 4),
            rating: Rating.good,
            elapsedMs: 10,
          ).toCompanion(),
        );

    await (db.delete(db.decks)..where((d) => d.id.equals('d1'))).go();

    expect(await db.select(db.flashcards).get(), isEmpty);
    expect(await db.select(db.reviewLogs).get(), isEmpty);
  });

  test('deleting a course cascades to its decks', () async {
    final db = await _open();
    await _seedDeck(db);
    await (db.delete(db.courses)..where((c) => c.id.equals('c1'))).go();
    expect(await db.select(db.decks).get(), isEmpty);
  });

  test('enums are stored by name', () async {
    final db = await _open();
    await _seedDeck(db);
    await db.into(db.flashcards).insert(_card('k1', 'd1').toCompanion());
    final row = await db
        .customSelect('SELECT source FROM flashcards')
        .getSingle();
    expect(row.read<String>('source'), 'photo');
  });

  test('dueAt round-trips with microsecond precision', () async {
    final db = await _open();
    await _seedDeck(db);
    final due = DateTime(2031, 5, 6, 7, 8, 9, 123, 456);
    await db
        .into(db.flashcards)
        .insert(_card('k1', 'd1', dueAt: due).toCompanion());
    final row = await db.select(db.flashcards).getSingle();
    expect(row.toModel().dueAt, due);
  });

  test('exam date keeps its calendar day', () async {
    final db = await _open();
    await db.into(db.courses).insert(_course('c1').toCompanion());
    final raw = await db
        .customSelect('SELECT exam_date FROM courses')
        .getSingle();
    expect(raw.read<String>('exam_date'), '2026-12-01');
    final row = await db.select(db.courses).getSingle();
    expect(row.toModel().examDate, DateTime(2026, 12, 1));
  });

  test('deck titles are unique per course ignoring case', () async {
    final db = await _open();
    await _seedDeck(db);
    await db
        .into(db.courses)
        .insert(_course('c2', title: 'Other').toCompanion());

    await expectLater(
      db
          .into(db.decks)
          .insert(
            const Deck(
              id: 'd2',
              courseId: 'c1',
              title: 'flutter',
            ).toCompanion(),
          ),
      throwsA(_sqliteCode(2067)),
    );
    await db
        .into(db.decks)
        .insert(
          const Deck(id: 'd3', courseId: 'c2', title: 'flutter').toCompanion(),
        );
  });

  group('blank text and ranges are rejected', () {
    test('blank deck title', () async {
      final db = await _open();
      await db.into(db.courses).insert(_course('c1').toCompanion());
      await expectLater(
        db
            .into(db.decks)
            .insert(
              const Deck(id: 'd1', courseId: 'c1', title: '   ').toCompanion(),
            ),
        throwsA(_sqliteCode(275)),
      );
    });

    test('empty card question', () async {
      final db = await _open();
      await _seedDeck(db);
      await expectLater(
        db
            .into(db.flashcards)
            .insert(_card('k1', 'd1').copyWith(question: '').toCompanion()),
        throwsA(_sqliteCode(275)),
      );
    });

    test('mastery, ease and interval out of range', () async {
      final db = await _open();
      await _seedDeck(db);
      final bad = [
        _card('k1', 'd1').copyWith(mastery: 1.5),
        _card('k2', 'd1').copyWith(ease: 1.0),
        _card('k3', 'd1').copyWith(intervalDays: -1),
      ];
      for (final card in bad) {
        await expectLater(
          db.into(db.flashcards).insert(card.toCompanion()),
          throwsA(_sqliteCode(275)),
          reason: card.id,
        );
      }
    });
  });

  test('every index exists', () async {
    final db = await _open();
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>{
        'flashcards_deck_id',
        'flashcards_due_at',
        'decks_course_id',
        'review_logs_card_id',
        'review_logs_reviewed_at',
      }),
    );
  });
}
