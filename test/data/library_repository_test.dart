import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/repositories/drift_library_repository.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';

import '../support/test_database.dart';

Course _course(String id, String title, DateTime exam) =>
    Course(id: id, title: title, examDate: exam);

Matcher _conflict(ConflictKind kind) =>
    isA<Conflict>().having((c) => c.kind, 'kind', kind);

void main() {
  late DriftLibraryRepository repo;

  setUp(() {
    final db = openTestDatabase();
    addTearDown(db.close);
    repo = DriftLibraryRepository(db);
  });

  test('insertCourse then watchCourses emits it', () async {
    final course = _course('c1', 'Mobile', DateTime(2026, 12, 1));
    await repo.insertCourse(course);
    expect(await repo.watchCourses().first, [course]);
  });

  test('courses ordered by exam date then title', () async {
    final a = _course('c1', 'B course', DateTime(2026, 12, 1));
    final b = _course('c2', 'A course', DateTime(2026, 12, 1));
    final c = _course('c3', 'Z course', DateTime(2026, 11, 1));
    for (final course in [a, b, c]) {
      await repo.insertCourse(course);
    }
    expect(await repo.watchCourses().first, [c, b, a]);
  });

  test('decks ordered by title', () async {
    await repo.insertCourse(_course('c1', 'Mobile', DateTime(2026, 12, 1)));
    const z = Deck(id: 'd1', courseId: 'c1', title: 'Zeta');
    const a = Deck(id: 'd2', courseId: 'c1', title: 'Alpha');
    await repo.insertDeck(z);
    await repo.insertDeck(a);
    expect(await repo.watchDecks().first, [a, z]);
  });

  test('deckById returns the deck, unknown id throws NotFound', () async {
    await repo.insertCourse(_course('c1', 'Mobile', DateTime(2026, 12, 1)));
    const deck = Deck(id: 'd1', courseId: 'c1', title: 'Alpha');
    await repo.insertDeck(deck);
    expect(await repo.deckById('d1'), deck);
    await expectLater(repo.deckById('nope'), throwsA(isA<NotFound>()));
  });

  test('insertDeck with unknown course throws NotFound(course)', () async {
    await expectLater(
      repo.insertDeck(const Deck(id: 'd1', courseId: 'nope', title: 'X')),
      throwsA(
        isA<NotFound>()
            .having((f) => f.entity, 'entity', 'course')
            .having((f) => f.id, 'id', 'nope'),
      ),
    );
  });

  test('duplicate deck id throws Conflict(duplicateId)', () async {
    await repo.insertCourse(_course('c1', 'Mobile', DateTime(2026, 12, 1)));
    await repo.insertDeck(const Deck(id: 'd1', courseId: 'c1', title: 'One'));
    await expectLater(
      repo.insertDeck(const Deck(id: 'd1', courseId: 'c1', title: 'Two')),
      throwsA(_conflict(ConflictKind.duplicateId)),
    );
  });

  test('duplicate deck title throws Conflict(duplicateTitle)', () async {
    await repo.insertCourse(_course('c1', 'Mobile', DateTime(2026, 12, 1)));
    await repo.insertDeck(const Deck(id: 'd1', courseId: 'c1', title: 'One'));
    await expectLater(
      repo.insertDeck(const Deck(id: 'd2', courseId: 'c1', title: 'ONE')),
      throwsA(_conflict(ConflictKind.duplicateTitle)),
    );
  });

  test('deleteDeck removes the deck', () async {
    await repo.insertCourse(_course('c1', 'Mobile', DateTime(2026, 12, 1)));
    await repo.insertDeck(const Deck(id: 'd1', courseId: 'c1', title: 'One'));
    await repo.deleteDeck('d1');
    expect(await repo.watchDecks().first, isEmpty);
  });

  test('deleteDeck unknown id throws NotFound', () async {
    await expectLater(
      repo.deleteDeck('missing'),
      throwsA(
        isA<NotFound>()
            .having((f) => f.entity, 'entity', 'deck')
            .having((f) => f.id, 'id', 'missing'),
      ),
    );
  });
}
