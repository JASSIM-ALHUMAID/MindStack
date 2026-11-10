import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/flashcard.dart';

import '../support/container.dart';
import '../support/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

Future<String> _deck(ProviderContainer container) async {
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  return library.createDeck(courseId: course, title: 'Deck');
}

void main() {
  test('addCard uses clock and id generator', () async {
    final container = makeContainer(
      clock: FixedClock(_now),
      ids: SequentialIds('k'),
    );
    final deck = await _deck(container);

    final id = await container
        .read(cardCommandsProvider)
        .addCard(
          deckId: deck,
          question: '  What? ',
          answer: ' That. ',
          source: CardSource.pdf,
          sourceRef: ' Page 2 ',
        );

    expect(id, 'k-3');
    final cards = await container.read(deckCardsProvider(deck).future);
    expect(cards, [
      Flashcard(
        id: 'k-3',
        deckId: deck,
        question: 'What?',
        answer: 'That.',
        source: CardSource.pdf,
        sourceRef: 'Page 2',
        dueAt: _now,
      ),
    ]);
  });

  test('addCard rejects a blank question or answer', () async {
    final container = makeContainer();
    final deck = await _deck(container);
    final commands = container.read(cardCommandsProvider);

    await expectLater(
      commands.addCard(deckId: deck, question: ' ', answer: 'a'),
      throwsA(
        isA<InvalidInput>().having(
          (e) => e.userMessage,
          'userMessage',
          'Enter a question.',
        ),
      ),
    );
    await expectLater(
      commands.addCard(deckId: deck, question: 'q', answer: ''),
      throwsA(
        isA<InvalidInput>().having(
          (e) => e.userMessage,
          'userMessage',
          'Enter an answer.',
        ),
      ),
    );
    expect(await container.read(deckCardsProvider(deck).future), isEmpty);
  });

  test('deleteCard unknown id throws NotFound', () async {
    final container = makeContainer();
    await expectLater(
      container.read(cardCommandsProvider).deleteCard('nope'),
      throwsA(isA<NotFound>()),
    );
  });

  test(
    'rateCard good on a new card persists intervalDays 1 and dueAt now+1d',
    () async {
      final container = makeContainer(clock: FixedClock(_now));
      final deck = await _deck(container);
      final commands = container.read(cardCommandsProvider);
      final id = await commands.addCard(
        deckId: deck,
        question: 'q',
        answer: 'a',
      );

      final rated = await commands.rateCard(id, Rating.good);

      expect(rated.intervalDays, 1);
      expect(rated.dueAt, _now.add(const Duration(days: 1)));
      final stored = (await container.read(deckCardsProvider(deck).future))
          .single;
      expect(stored, rated);
      expect(stored.repetitions, 1);
    },
  );

  test('rateCard unknown id throws NotFound', () async {
    final container = makeContainer();
    await expectLater(
      container.read(cardCommandsProvider).rateCard('nope', Rating.good),
      throwsA(isA<NotFound>()),
    );
  });

  test('editing a card keeps intervalDays, ease and dueAt', () async {
    final container = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(container);
    final commands = container.read(cardCommandsProvider);
    final id = await commands.addCard(deckId: deck, question: 'q', answer: 'a');
    final rated = await commands.rateCard(id, Rating.good);

    final edited = await commands.updateCard(
      id: id,
      question: '  New q ',
      answer: ' New a ',
    );

    expect(edited, rated.copyWith(question: 'New q', answer: 'New a'));
    final stored = (await container.read(deckCardsProvider(deck).future))
        .single;
    expect(stored, edited);
    expect(stored.intervalDays, rated.intervalDays);
    expect(stored.ease, rated.ease);
    expect(stored.dueAt, rated.dueAt);
    expect(stored.mastery, rated.mastery);
  });

  test('updateCard rejects a blank question and leaves the card', () async {
    final container = makeContainer();
    final deck = await _deck(container);
    final commands = container.read(cardCommandsProvider);
    final id = await commands.addCard(deckId: deck, question: 'q', answer: 'a');

    await expectLater(
      commands.updateCard(id: id, question: '  ', answer: 'b'),
      throwsA(
        isA<InvalidInput>().having(
          (e) => e.userMessage,
          'userMessage',
          'Enter a question.',
        ),
      ),
    );
    final stored = (await container.read(deckCardsProvider(deck).future))
        .single;
    expect((stored.question, stored.answer), ('q', 'a'));
  });

  test('updateCard unknown id throws NotFound', () async {
    final container = makeContainer();
    await expectLater(
      container
          .read(cardCommandsProvider)
          .updateCard(id: 'nope', question: 'q', answer: 'a'),
      throwsA(isA<NotFound>()),
    );
  });

  test('restoreCard undoes deleteCard with its review logs', () async {
    final container = makeContainer();
    final deck = await _deck(container);
    final commands = container.read(cardCommandsProvider);
    final id = await commands.addCard(deckId: deck, question: 'q', answer: 'a');
    final rated = await commands.rateCard(id, Rating.good);
    final logs = container.read(reviewLogRepositoryProvider);

    final deleted = await commands.deleteCard(id);

    expect(deleted.card, rated);
    expect(deleted.logs, hasLength(1));
    expect(await _cards(container, deck), isEmpty);
    expect(await logs.watchAll().first, isEmpty);

    await commands.restoreCard(deleted);

    expect(await _cards(container, deck), [rated]);
    expect(await logs.watchAll().first, deleted.logs);
  });

  test('deck mastery of an empty deck is 0, also after deleting the last '
      'card', () async {
    final container = makeContainer();
    final deck = await _deck(container);

    final empty = (await container.read(deckStatsProvider.future))[deck]!;
    expect((empty.cardCount, empty.mastery), (0, 0.0));

    final commands = container.read(cardCommandsProvider);
    final id = await commands.addCard(deckId: deck, question: 'q', answer: 'a');
    await commands.rateCard(id, Rating.easy);
    await commands.deleteCard(id);

    final stats = await container
        .read(cardRepositoryProvider)
        .watchDeckStats()
        .first;
    expect((stats[deck]!.cardCount, stats[deck]!.mastery), (0, 0.0));
  });

  test('deckStatsProvider updates after addCard', () async {
    final container = makeContainer();
    final deck = await _deck(container);
    final updates = <int>[];
    container.listen(deckStatsProvider, (_, next) {
      final stats = next.value;
      if (stats != null) updates.add(stats[deck]?.cardCount ?? -1);
    }, fireImmediately: true);
    await container.read(deckStatsProvider.future);

    await container
        .read(cardCommandsProvider)
        .addCard(deckId: deck, question: 'q', answer: 'a');
    await Future<void>.delayed(Duration.zero);
    await container.pump();

    expect(updates.last, 1);
    expect(updates.first, 0);
  });
}

/// The stored cards of [deckId], read straight from the repository so no
/// auto-disposed provider value is reused between reads.
Future<List<Flashcard>> _cards(ProviderContainer container, String deckId) =>
    container.read(cardRepositoryProvider).watchByDeck(deckId).first;
