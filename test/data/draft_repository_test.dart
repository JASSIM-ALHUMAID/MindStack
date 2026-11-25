import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/repositories/drift_draft_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/draft_card.dart';

import '../support/test_database.dart';

DraftCard _draft(String id, {bool selected = true, int? position}) => DraftCard(
  id: id,
  source: CardSource.slide,
  sourceRef: 'Page 1',
  question: 'Q $id',
  answer: 'A $id',
  selected: selected,
  position: position,
);

Future<List<String>> _ids(DriftDraftRepository repo) async => [
  for (final d in await repo.watchAll().first) d.id,
];

void main() {
  late DriftDraftRepository repo;

  setUp(() {
    final db = openTestDatabase();
    addTearDown(db.close);
    repo = DriftDraftRepository(db);
  });

  test('insertAll then watchAll emits drafts in insertion order', () async {
    await repo.insertAll([_draft('b'), _draft('a'), _draft('c')]);
    expect(await repo.watchAll().first, [
      _draft('b', position: 1),
      _draft('a', position: 2),
      _draft('c', position: 3),
    ]);
  });

  test('a later insertAll is listed after the existing drafts', () async {
    await repo.insertAll([_draft('a'), _draft('b')]);
    await repo.insertAll([_draft('c')]);
    expect(await _ids(repo), ['a', 'b', 'c']);
    expect((await repo.watchAll().first).last.position, 3);
  });

  test('re-inserting a deleted draft restores its place', () async {
    await repo.insertAll([_draft('a'), _draft('b'), _draft('c')]);
    final deleted = (await repo.watchAll().first)[1];

    await repo.delete(['b']);
    await repo.insertAll([deleted]);

    expect(await _ids(repo), ['a', 'b', 'c']);
    expect((await repo.watchAll().first)[1], deleted);
  });

  test('a restored first draft returns to the top', () async {
    await repo.insertAll([_draft('a'), _draft('b')]);
    final deleted = (await repo.watchAll().first).first;

    await repo.delete(['a']);
    await repo.insertAll([deleted]);

    expect(await _ids(repo), ['a', 'b']);
  });

  test('selected keeps the list order', () async {
    await repo.insertAll([_draft('a'), _draft('b'), _draft('c')]);
    final deleted = (await repo.watchAll().first).first;
    await repo.delete(['a']);
    await repo.insertAll([deleted]);

    expect([for (final d in await repo.selected()) d.id], ['a', 'b', 'c']);
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
    expect(await repo.selected(), [_draft('a', position: 1)]);
  });

  test('delete removes only the given ids', () async {
    await repo.insertAll([_draft('a'), _draft('b'), _draft('c')]);
    await repo.delete(['a', 'c']);
    expect(await _ids(repo), ['b']);
  });

  test('clear removes all', () async {
    await repo.insertAll([_draft('a'), _draft('b')]);
    await repo.clear();
    expect(await repo.watchAll().first, isEmpty);
  });
}
