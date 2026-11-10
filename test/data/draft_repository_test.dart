import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/repositories/drift_draft_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/draft_card.dart';

import '../support/test_database.dart';

DraftCard _draft(String id, {bool selected = true}) => DraftCard(
  id: id,
  source: CardSource.slide,
  sourceRef: 'Page 1',
  question: 'Q $id',
  answer: 'A $id',
  selected: selected,
);

void main() {
  late DriftDraftRepository repo;

  setUp(() {
    final db = openTestDatabase();
    addTearDown(db.close);
    repo = DriftDraftRepository(db);
  });

  test('insertAll then watchAll emits drafts in insertion order', () async {
    final drafts = [_draft('b'), _draft('a'), _draft('c')];
    await repo.insertAll(drafts);
    expect(await repo.watchAll().first, drafts);
  });

  test('insertAll with a duplicate id inserts nothing', () async {
    await expectLater(
      repo.insertAll([_draft('a'), _draft('a')]),
      throwsA(isA<Conflict>()),
    );
    expect(await repo.watchAll().first, isEmpty);
  });

  test('toggleSelected twice restores the original value', () async {
    await repo.insertAll([_draft('a')]);
    await repo.toggleSelected('a');
    expect((await repo.watchAll().first).single.selected, isFalse);
    await repo.toggleSelected('a');
    expect((await repo.watchAll().first).single.selected, isTrue);
  });

  test('toggleSelected unknown id throws NotFound', () async {
    await expectLater(
      repo.toggleSelected('missing'),
      throwsA(
        isA<NotFound>()
            .having((f) => f.entity, 'entity', 'draft')
            .having((f) => f.id, 'id', 'missing'),
      ),
    );
  });

  test('updateText changes only question and answer', () async {
    await repo.insertAll([_draft('a', selected: false)]);

    await repo.updateText('a', question: 'New Q', answer: 'New A');

    final updated = (await repo.watchAll().first).single;
    expect(updated.question, 'New Q');
    expect(updated.answer, 'New A');
    expect(updated.selected, isFalse);
    expect(updated.source, CardSource.slide);
    expect(updated.sourceRef, 'Page 1');
  });

  test('updateText unknown id throws NotFound', () async {
    await expectLater(
      repo.updateText('missing', question: 'Q', answer: 'A'),
      throwsA(isA<NotFound>().having((f) => f.entity, 'entity', 'draft')),
    );
  });

  test('selected returns only ticked drafts', () async {
    await repo.insertAll([_draft('a'), _draft('b', selected: false)]);
    expect(await repo.selected(), [_draft('a')]);
  });

  test('delete removes only the given ids', () async {
    await repo.insertAll([_draft('a'), _draft('b'), _draft('c')]);
    await repo.delete(['a', 'c']);
    expect(await repo.watchAll().first, [_draft('b')]);
  });

  test('clear removes all', () async {
    await repo.insertAll([_draft('a'), _draft('b')]);
    await repo.clear();
    expect(await repo.watchAll().first, isEmpty);
  });
}
