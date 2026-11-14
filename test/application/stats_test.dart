import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/stats.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/streak.dart';

import '../support/container.dart';
import '../support/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

/// Waits until [provider] has data, then returns it.
Future<T> _value<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) async {
  final sub = container.listen(provider, (_, _) {}, fireImmediately: true);
  addTearDown(sub.close);
  for (var i = 0; i < 50; i++) {
    final value = sub.read();
    // requireValue rethrows a load error.
    if (value.hasValue || value.hasError) return value.requireValue;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('no value');
}

/// A course with deck "Deck" holding cards Q1..Q[count]; returns the deck id
/// and the card ids.
Future<(String, List<String>)> _deck(
  ProviderContainer container,
  int count, {
  String title = 'Deck',
}) async {
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course $title',
    examDate: DateTime(2026, 12, 1),
  );
  final deck = await library.createDeck(courseId: course, title: title);
  final cards = container.read(cardCommandsProvider);
  return (
    deck,
    [
      for (var i = 1; i <= count; i++)
        await cards.addCard(deckId: deck, question: 'Q$i', answer: 'A$i'),
    ],
  );
}

void main() {
  test('no reviews gives streak 0 and an empty weakest list', () async {
    final container = makeContainer(clock: FixedClock(_now));
    await _deck(container, 3);

    final streak = await _value(container, streakProvider);
    expect(streak.current, 0);
    expect(streak.isEmpty, isTrue);
    expect(await _value(container, weakestCardsProvider), isEmpty);
  });

  test('reviewing on 3 consecutive days gives streak 3', () async {
    final clock = FixedClock(_now);
    final container = makeContainer(clock: clock);
    final (_, ids) = await _deck(container, 1);
    final cards = container.read(cardCommandsProvider);

    for (var day = 0; day < 3; day++) {
      await cards.rateCard(ids.single, Rating.good);
      clock.advance(const Duration(days: 1));
    }
    // Back to the third review day, so today counts.
    clock.advance(const Duration(days: -1));

    final streak = await _value(container, streakProvider);
    expect((streak.current, streak.best, streak.studyDays), (3, 3, 3));
    expect(streak.days.last, isTrue);
    expect(streak.days, hasLength(kStreakGridDays));
  });

  test('weakest cards are reviewed cards only, lowest mastery first, at '
      'most 3', () async {
    final container = makeContainer(clock: FixedClock(_now));
    final (_, ids) = await _deck(container, 5);
    final cards = container.read(cardCommandsProvider);
    // ids[4] is never reviewed, so it is not listed despite mastery 0.
    // Mastery after: 0.30, 0.15, 0.10 and 0.
    await cards.rateCard(ids[0], Rating.easy);
    await cards.rateCard(ids[0], Rating.easy);
    await cards.rateCard(ids[1], Rating.easy);
    await cards.rateCard(ids[2], Rating.good);
    await cards.rateCard(ids[3], Rating.again);

    final weakest = await _value(container, weakestCardsProvider);

    expect([for (final c in weakest) c.id], [ids[3], ids[2], ids[1]]);
  });

  test('mastery by deck lists every deck, an empty deck at 0', () async {
    final container = makeContainer(clock: FixedClock(_now));
    final (full, ids) = await _deck(container, 2, title: 'Full');
    final (empty, _) = await _deck(container, 0, title: 'Empty');
    await container.read(cardCommandsProvider).rateCard(ids[0], Rating.easy);

    final decks = await _value(container, masteryByDeckProvider);
    final byId = {for (final d in decks) d.deckId: d};

    expect(byId[empty]!.cardCount, 0);
    expect(byId[empty]!.mastery, 0);
    expect(byId[full]!.cardCount, 2);
    expect(byId[full]!.mastery, greaterThan(0));
    // Weighted by cards: the empty deck does not pull the average down.
    expect(averageMastery(decks), closeTo(byId[full]!.mastery, 1e-9));
    expect(averageMastery(const []), 0);
  });
}
