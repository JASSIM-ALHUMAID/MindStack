import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:mindstack/data/repositories/drift_card_repository.dart';
import 'package:mindstack/data/repositories/drift_library_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/models/deck_stats.dart';
import 'package:mindstack/domain/models/flashcard.dart';

import '../support/test_database.dart';

final _now = DateTime(2026, 11, 4, 12);

Flashcard _card(
  String id, {
  String deckId = 'd1',
  DateTime? dueAt,
  double mastery = 0,
}) => Flashcard(
  id: id,
  deckId: deckId,
  question: 'Q $id',
  answer: 'A $id',
  dueAt: dueAt ?? _now,
  mastery: mastery,
);

void main() {
  late AppDatabase db;
  late DriftCardRepository repo;

  setUp(() async {
    db = openTestDatabase();
    addTearDown(db.close);
    repo = DriftCardRepository(db);
    final library = DriftLibraryRepository(db);
    await library.insertCourse(
      Course(id: 'c1', title: 'Course', examDate: DateTime(2026, 12, 1)),
    );
    for (final id in ['d1', 'd2', 'd3']) {
      await library.insertDeck(Deck(id: id, courseId: 'c1', title: 'Deck $id'));
    }
  });

  test(
    'insert then watchByDeck emits only that deck\'s cards in order',
    () async {
      final first = _card('k2');
      final second = _card('k1');
      await repo.insert(first);
      await repo.insert(_card('other', deckId: 'd2'));
      await repo.insert(second);
      expect(await repo.watchByDeck('d1').first, [first, second]);
    },
  );

  test('byId returns the stored card', () async {
    final card = _card('k1');
    await repo.insert(card);
    expect(await repo.byId('k1'), card);
  });

  test('byId unknown id throws NotFound', () async {
    await expectLater(repo.byId('nope'), throwsA(isA<NotFound>()));
  });

  test('insert duplicate id throws Conflict(duplicateId)', () async {
    await repo.insert(_card('k1'));
    await expectLater(
      repo.insert(_card('k1')),
      throwsA(
        isA<Conflict>().having((c) => c.kind, 'kind', ConflictKind.duplicateId),
      ),
    );
  });

  test('insert into unknown deck throws NotFound(deck)', () async {
    await expectLater(
      repo.insert(_card('k1', deckId: 'nope')),
      throwsA(isA<NotFound>().having((f) => f.entity, 'entity', 'deck')),
    );
  });

  test('insertAll is atomic', () async {
    await expectLater(
      repo.insertAll([_card('k1'), _card('k2', deckId: 'nope')]),
      throwsA(isA<NotFound>()),
    );
    expect(await repo.watchAll().first, isEmpty);
  });

  test('update unknown id throws NotFound', () async {
    await expectLater(
      repo.update(_card('missing')),
      throwsA(
        isA<NotFound>()
            .having((f) => f.entity, 'entity', 'card')
            .having((f) => f.id, 'id', 'missing'),
      ),
    );
  });

  test('update keeps every field', () async {
    await repo.insert(_card('k1'));
    final changed = Flashcard(
      id: 'k1',
      deckId: 'd2',
      question: 'New question',
      answer: 'New answer',
      source: CardSource.manual,
      intervalDays: 6,
      ease: 1.9,
      repetitions: 3,
      dueAt: DateTime(2027, 1, 2, 3, 4, 5),
      mastery: 0.75,
    );
    await repo.update(changed);
    expect(await repo.watchAll().first, [changed]);
  });

  test(
    'due returns cards with dueAt <= now, optionally filtered by deck',
    () async {
      final early = _card('k1', dueAt: _now.subtract(const Duration(days: 1)));
      final exact = _card('k2', deckId: 'd2');
      final later = _card('k3', dueAt: _now.add(const Duration(seconds: 1)));
      await repo.insertAll([early, exact, later]);
      expect(await repo.due(now: _now), [early, exact]);
      expect(await repo.due(now: _now, deckId: 'd2'), [exact]);
    },
  );

  test('moveToDeck returns moved count and moves only that deck', () async {
    await repo.insertAll([_card('k1'), _card('k2'), _card('k3', deckId: 'd3')]);
    expect(await repo.moveToDeck(fromDeckId: 'd1', toDeckId: 'd2'), 2);
    expect(await repo.watchByDeck('d2').first, hasLength(2));
    expect(await repo.watchByDeck('d3').first, hasLength(1));
    expect(await repo.watchByDeck('d1').first, isEmpty);
  });

  test('moveToDeck into unknown deck throws NotFound', () async {
    await repo.insert(_card('k1'));
    await expectLater(
      repo.moveToDeck(fromDeckId: 'd1', toDeckId: 'nope'),
      throwsA(isA<NotFound>()),
    );
  });

  test(
    'watchDeckStats includes empty decks with count 0 and mastery 0',
    () async {
      final stats = await repo.watchDeckStats().first;
      expect(stats.keys, unorderedEquals(['d1', 'd2', 'd3']));
      expect(
        stats['d1'],
        const DeckStats(deckId: 'd1', cardCount: 0, mastery: 0),
      );
    },
  );

  test('watchDeckStats averages mastery', () async {
    await repo.insertAll([
      _card('k1', mastery: 0.2),
      _card('k2', mastery: 0.6),
      _card('k3', deckId: 'd2', mastery: 1),
    ]);
    final stats = await repo.watchDeckStats().first;
    expect(stats['d1']!.cardCount, 2);
    expect(stats['d1']!.mastery, closeTo(0.4, 1e-9));
    expect(stats['d2']!.cardCount, 1);
    expect(stats['d2']!.mastery, 1);
  });

  test('watchDeckStats re-emits when cards change', () async {
    final emissions = <int>[];
    final sub = repo.watchDeckStats().listen(
      (s) => emissions.add(s['d1']!.cardCount),
    );
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await repo.insert(_card('k1'));
    await pumpEventQueue();
    expect(emissions, [0, 1]);
  });

  test('watchAll re-emits after delete', () async {
    await repo.insert(_card('k1'));
    final emissions = <int>[];
    final sub = repo.watchAll().listen((c) => emissions.add(c.length));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await repo.delete('k1');
    await pumpEventQueue();
    expect(emissions, [1, 0]);
  });

  test('delete unknown id throws NotFound', () async {
    await expectLater(repo.delete('missing'), throwsA(isA<NotFound>()));
  });
}
