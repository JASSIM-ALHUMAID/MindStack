import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/repositories/drift_card_repository.dart';
import 'package:mindstack/data/repositories/drift_library_repository.dart';
import 'package:mindstack/data/repositories/drift_review_log_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/models/review_log.dart';

import '../support/test_database.dart';

ReviewLog _log(String id, String cardId) => ReviewLog(
  id: id,
  cardId: cardId,
  reviewedAt: DateTime(2026, 11, 4, 9),
  rating: Rating.good,
  elapsedMs: 1200,
);

void main() {
  late DriftReviewLogRepository repo;
  late DriftCardRepository cards;

  setUp(() async {
    final db = openTestDatabase();
    addTearDown(db.close);
    repo = DriftReviewLogRepository(db);
    cards = DriftCardRepository(db);
    final library = DriftLibraryRepository(db);
    await library.insertCourse(
      Course(id: 'c1', title: 'Course', examDate: DateTime(2026, 12, 1)),
    );
    await library.insertDeck(const Deck(id: 'd1', courseId: 'c1', title: 'D'));
    await cards.insert(
      Flashcard(
        id: 'k1',
        deckId: 'd1',
        question: 'Q',
        answer: 'A',
        dueAt: DateTime(2026, 11, 4),
      ),
    );
  });

  test('insert then watchAll emits it', () async {
    await repo.insert(_log('r1', 'k1'));
    expect(await repo.watchAll().first, [_log('r1', 'k1')]);
  });

  test('insert for unknown card throws NotFound(card)', () async {
    await expectLater(
      repo.insert(_log('r1', 'nope')),
      throwsA(
        isA<NotFound>()
            .having((f) => f.entity, 'entity', 'card')
            .having((f) => f.id, 'id', 'nope'),
      ),
    );
  });

  test('insert duplicate id throws Conflict(duplicateId)', () async {
    await repo.insert(_log('r1', 'k1'));
    await expectLater(repo.insert(_log('r1', 'k1')), throwsA(isA<Conflict>()));
  });

  test('deleting the card cascades to its logs', () async {
    await repo.insert(_log('r1', 'k1'));
    await cards.delete('k1');
    expect(await repo.watchAll().first, isEmpty);
  });
}
