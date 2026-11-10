import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/inbox.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/data/repositories/drift_draft_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/draft_card.dart';
import 'package:mindstack/domain/repositories.dart';

import '../support/container.dart';
import '../support/fakes.dart';

/// Delegates to [_inner] except that [delete] always fails.
final class _FailingDeleteDrafts implements DraftRepository {
  _FailingDeleteDrafts(this._inner);

  final DraftRepository _inner;

  @override
  Stream<List<DraftCard>> watchAll() => _inner.watchAll();

  @override
  Future<List<DraftCard>> selected() => _inner.selected();

  @override
  Future<void> insertAll(List<DraftCard> drafts) => _inner.insertAll(drafts);

  @override
  Future<void> toggleSelected(String id) => _inner.toggleSelected(id);

  @override
  Future<void> updateText(
    String id, {
    required String question,
    required String answer,
  }) => _inner.updateText(id, question: question, answer: answer);

  @override
  Future<void> delete(Iterable<String> ids) async =>
      throw StorageFailure(StateError('disk full'), StackTrace.current);

  @override
  Future<void> clear() => _inner.clear();
}

final _now = DateTime(2026, 11, 4, 12);

String _fixture(String path) =>
    File('test/fixtures/mindstack/$path').readAsStringSync();

DraftCard _draft(String id, {bool selected = true}) => DraftCard(
  id: id,
  source: CardSource.photo,
  sourceRef: 'Whiteboard $id',
  question: 'Q $id',
  answer: 'A $id',
  selected: selected,
);

Future<String> _deck(ProviderContainer container) async {
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  return library.createDeck(courseId: course, title: 'Deck');
}

void main() {
  test(
    'saveSelectedTo creates cards in the deck and removes only ticked drafts',
    () async {
      final container = makeContainer(clock: FixedClock(_now));
      final deck = await _deck(container);
      await container.read(draftRepositoryProvider).insertAll([
        _draft('a'),
        _draft('b', selected: false),
        _draft('c'),
      ]);

      final saved = await container
          .read(inboxCommandsProvider)
          .saveSelectedTo(deck);

      expect(saved, 2);
      final cards = await container.read(deckCardsProvider(deck).future);
      expect([for (final c in cards) c.question], ['Q a', 'Q c']);
      expect(cards.first.source, CardSource.photo);
      expect(cards.first.sourceRef, 'Whiteboard a');
      expect(cards.first.dueAt, _now);
      final drafts = await container.read(draftsProvider.future);
      expect([for (final d in drafts) d.id], ['b']);
    },
  );

  test('saveSelectedTo with nothing ticked throws InvalidInput', () async {
    final container = makeContainer();
    final deck = await _deck(container);
    await container.read(draftRepositoryProvider).insertAll([
      _draft('a', selected: false),
    ]);

    await expectLater(
      container.read(inboxCommandsProvider).saveSelectedTo(deck),
      throwsA(
        isA<InvalidInput>().having(
          (e) => e.userMessage,
          'userMessage',
          'Tick at least one draft to save.',
        ),
      ),
    );
  });

  test(
    'saveSelectedTo into a missing deck throws NotFound, drafts unchanged',
    () async {
      final container = makeContainer();
      await container.read(draftRepositoryProvider).insertAll([
        _draft('a'),
        _draft('b'),
      ]);

      await expectLater(
        container.read(inboxCommandsProvider).saveSelectedTo('missing-deck'),
        throwsA(isA<NotFound>()),
      );

      final drafts = await container.read(draftsProvider.future);
      expect([for (final d in drafts) d.id], ['a', 'b']);
      expect(await container.read(allCardsProvider.future), isEmpty);
    },
  );

  test(
    'saveSelectedTo rolls back inserted cards when deleting drafts fails',
    () async {
      final container = makeContainer(
        overrides: [
          draftRepositoryProvider.overrideWith(
            (ref) => _FailingDeleteDrafts(
              DriftDraftRepository(ref.watch(databaseProvider)),
            ),
          ),
        ],
      );
      final deck = await _deck(container);
      await container.read(draftRepositoryProvider).insertAll([
        _draft('a'),
        _draft('b', selected: false),
        _draft('c'),
      ]);

      await expectLater(
        container.read(inboxCommandsProvider).saveSelectedTo(deck),
        throwsA(isA<StorageFailure>()),
      );

      // The cards were inserted before the failure, so only a rollback removes them.
      expect(await container.read(deckCardsProvider(deck).future), isEmpty);
      final drafts = await container.read(draftsProvider.future);
      expect(
        [for (final d in drafts) (d.id, d.selected)],
        [('a', true), ('b', false), ('c', true)],
      );
    },
  );

  test('toggle twice restores selection', () async {
    final container = makeContainer();
    await container.read(draftRepositoryProvider).insertAll([_draft('a')]);
    final inbox = container.read(inboxCommandsProvider);

    await inbox.toggle('a');
    expect(await container.read(draftRepositoryProvider).selected(), isEmpty);
    await inbox.toggle('a');
    expect(
      await container.read(draftRepositoryProvider).selected(),
      hasLength(1),
    );
  });

  group('updateDraft', () {
    test('trims and saves the text, keeps the tick', () async {
      final container = makeContainer();
      await container.read(draftRepositoryProvider).insertAll([
        _draft('a', selected: false),
      ]);

      await container
          .read(inboxCommandsProvider)
          .updateDraft(id: 'a', question: '  New Q ', answer: ' New A  ');

      final draft = (await container.read(draftsProvider.future)).single;
      expect((draft.question, draft.answer), ('New Q', 'New A'));
      expect(draft.selected, isFalse);
    });

    test('blank question throws InvalidInput and changes nothing', () async {
      final container = makeContainer();
      await container.read(draftRepositoryProvider).insertAll([_draft('a')]);

      await expectLater(
        container
            .read(inboxCommandsProvider)
            .updateDraft(id: 'a', question: '   ', answer: 'New A'),
        throwsA(
          isA<InvalidInput>().having(
            (e) => e.userMessage,
            'userMessage',
            'Enter a question.',
          ),
        ),
      );
      expect((await container.read(draftsProvider.future)).single, _draft('a'));
    });

    test('missing draft throws NotFound', () async {
      final container = makeContainer();

      await expectLater(
        container
            .read(inboxCommandsProvider)
            .updateDraft(id: 'gone', question: 'Q', answer: 'A'),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('importDeck', () {
    test(
      'adds each card as a ticked shared draft after existing ones',
      () async {
        final container = makeContainer();
        await container.read(draftRepositoryProvider).insertAll([
          _draft('old'),
        ]);

        final deck = await container
            .read(inboxCommandsProvider)
            .importDeck(_fixture('valid/01_flutter_widgets.mindstack'));

        expect(deck.deckTitle, 'Flutter Widgets');
        final drafts = await container.read(draftsProvider.future);
        expect(drafts, hasLength(6));
        expect(drafts.first.id, 'old');
        final imported = drafts.skip(1).toList();
        expect(imported.first.question, 'What is a Widget?');
        for (final d in imported) {
          expect(d.source, CardSource.shared);
          expect(d.sourceRef, 'Flutter Widgets');
          expect(d.selected, isTrue);
        }
        expect({for (final d in imported) d.id}, hasLength(5));
      },
    );

    test('importing the same file twice keeps both copies', () async {
      final container = makeContainer();
      final inbox = container.read(inboxCommandsProvider);
      final text = _fixture('valid/04_single_card.mindstack');

      await inbox.importDeck(text);
      await inbox.importDeck(text);

      expect(await container.read(draftsProvider.future), hasLength(2));
    });

    test(
      'a bad file throws InvalidInput with the reason, adds nothing',
      () async {
        final container = makeContainer();
        await container.read(draftRepositoryProvider).insertAll([_draft('a')]);

        await expectLater(
          container
              .read(inboxCommandsProvider)
              .importDeck(
                _fixture('invalid/bad_05_card_missing_answer.mindstack'),
              ),
          throwsA(
            isA<InvalidInput>().having(
              (e) => e.userMessage,
              'userMessage',
              'Card 1 has no answer.',
            ),
          ),
        );
        final drafts = await container.read(draftsProvider.future);
        expect([for (final d in drafts) d.id], ['a']);
      },
    );
  });

  test('clear removes every draft', () async {
    final container = makeContainer();
    await container.read(draftRepositoryProvider).insertAll([
      _draft('a'),
      _draft('b', selected: false),
    ]);

    await container.read(inboxCommandsProvider).clear();

    expect(await container.read(draftRepositoryProvider).selected(), isEmpty);
    expect(await container.read(draftsProvider.future), isEmpty);
  });
}
