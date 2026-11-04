import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/inbox.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/draft_card.dart';

import '../support/container.dart';
import '../support/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

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

  test('saveSelectedTo rolls back when inserting cards fails', () async {
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
  });

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
