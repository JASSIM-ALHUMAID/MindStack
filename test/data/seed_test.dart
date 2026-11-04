import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:mindstack/data/sample_data.dart';
import 'package:mindstack/data/seed.dart';
import 'package:mindstack/domain/failures.dart';

import '../support/test_database.dart';

Future<int> _count(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT count(*) AS n FROM $table')
      .getSingle();
  return row.read<int>('n');
}

void main() {
  final sample = buildSampleData(DateTime(2026, 11, 4, 12));
  late AppDatabase db;

  setUp(() {
    db = openTestDatabase();
    addTearDown(db.close);
  });

  Future<List<int>> counts() async => [
    await _count(db, 'courses'),
    await _count(db, 'decks'),
    await _count(db, 'flashcards'),
    await _count(db, 'draft_cards'),
    await _count(db, 'meta'),
  ];

  test('seeds 2 courses, 4 decks, 9 cards and the sample drafts', () async {
    expect(sample.courses, hasLength(2));
    expect(sample.decks, hasLength(4));
    expect(sample.cards, hasLength(9));
    await seedIfNeeded(db, sample);
    expect(await counts(), [
      sample.courses.length,
      sample.decks.length,
      sample.cards.length,
      sample.drafts.length,
      1,
    ]);
  });

  test('second call adds nothing', () async {
    await seedIfNeeded(db, sample);
    await seedIfNeeded(db, sample);
    expect(await counts(), [
      sample.courses.length,
      sample.decks.length,
      sample.cards.length,
      sample.drafts.length,
      1,
    ]);
  });

  test('seed that fails half-way leaves no rows and no flag', () async {
    final broken = SeedData(
      courses: sample.courses,
      decks: sample.decks,
      cards: [
        ...sample.cards,
        sample.cards.first.copyWith(deckId: 'missing'),
      ],
      drafts: sample.drafts,
    );
    await expectLater(seedIfNeeded(db, broken), throwsA(isA<AppFailure>()));
    expect(await counts(), [0, 0, 0, 0, 0]);
  });

  test('deleting everything then seeding again adds nothing', () async {
    await seedIfNeeded(db, sample);
    await db.delete(db.courses).go();
    await db.delete(db.draftCards).go();
    await seedIfNeeded(db, sample);
    expect(await counts(), [0, 0, 0, 0, 1]);
  });
}
