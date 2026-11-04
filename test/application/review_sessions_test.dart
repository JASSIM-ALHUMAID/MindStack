import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/review.dart';
import 'package:mindstack/data/drift_transaction_runner.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/repositories.dart';

import '../support/container.dart';
import '../support/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

Future<String> _deck(ProviderContainer c, String title) async {
  final commands = c.read(libraryCommandsProvider);
  final course = await commands.createCourse(
    title: 'Course $title',
    examDate: DateTime(2026, 12, 1),
  );
  return commands.createDeck(courseId: course, title: title);
}

Future<String> _card(ProviderContainer c, String deck, String question) => c
    .read(cardCommandsProvider)
    .addCard(deckId: deck, question: question, answer: 'Answer');

/// Simulates database latency using the same controllable clock as Review.
final class _TimedRunner implements TransactionRunner {
  const _TimedRunner(this.inner, this.clock);

  final TransactionRunner inner;
  final FixedClock clock;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    final result = await inner.run(action);
    clock.advance(const Duration(seconds: 10));
    return result;
  }
}

void main() {
  test('a fresh session includes a card added after initial loading', () async {
    final c = makeContainer();
    final deck = await _deck(c, 'A');
    await c.read(reviewProvider.future);
    final added = await _card(c, deck, 'New card');

    await c.read(reviewProvider.notifier).start();

    expect(c.read(reviewProvider).requireValue.cardIds, [added]);
  });

  test('a new due session excludes cards already rated good', () async {
    final c = makeContainer();
    final deck = await _deck(c, 'A');
    await _card(c, deck, 'Question');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);
    await notifier.rate(Rating.good);

    await notifier.start();

    expect(c.read(reviewProvider).requireValue.cardIds, isEmpty);
    expect(c.read(reviewProvider).requireValue.finished, isTrue);
  });

  test(
    'explicit ids preserve order, deduplicate and allow future cards',
    () async {
      final c = makeContainer();
      final deck = await _deck(c, 'A');
      final a = await _card(c, deck, 'A');
      final b = await _card(c, deck, 'B');
      final cards = c.read(cardRepositoryProvider);
      await cards.update(
        (await cards.byId(b))
            .copyWith(dueAt: _now.add(const Duration(days: 7))),
      );
      await c.read(reviewProvider.future);

      await c
          .read(reviewProvider.notifier)
          .start(cardIds: [b, a, b, 'missing']);

      expect(c.read(reviewProvider).requireValue.cardIds, [b, a]);
    },
  );

  test(
    'explicit empty ids do not fall back to the general due queue',
    () async {
      final c = makeContainer();
      final deck = await _deck(c, 'A');
      await _card(c, deck, 'A');
      await c.read(reviewProvider.future);

      await c.read(reviewProvider.notifier).start(cardIds: []);

      expect(c.read(reviewProvider).requireValue.cardIds, isEmpty);
    },
  );

  test('a targeted start during initial build retains its selection', () async {
    final c = makeContainer();
    final deck = await _deck(c, 'A');
    final a = await _card(c, deck, 'A');
    await _card(c, deck, 'B');
    // Do not await reviewProvider.future before starting the selected session.
    await c.read(reviewProvider.notifier).start(cardIds: [a]);

    expect(c.read(reviewProvider).requireValue.cardIds, [a]);
  });

  test('rating records each card time without database latency', () async {
    final clock = FixedClock(_now);
    final c = makeContainer(
      clock: clock,
      overrides: [
        transactionRunnerProvider.overrideWith(
          (ref) => _TimedRunner(
            DriftTransactionRunner(ref.watch(databaseProvider)),
            clock,
          ),
        ),
      ],
    );
    final deck = await _deck(c, 'A');
    final a = await _card(c, deck, 'A');
    final b = await _card(c, deck, 'B');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);
    await notifier.start(cardIds: [a, b]);

    clock.advance(const Duration(milliseconds: 2500));
    await notifier.rate(Rating.good);
    clock.advance(const Duration(milliseconds: 1200));
    await notifier.rate(Rating.easy);

    final logs = await c.read(reviewLogRepositoryProvider).watchAll().first;
    expect(logs.map((log) => log.cardId), [a, b]);
    expect(logs.map((log) => log.elapsedMs), [2500, 1200]);
  });

  test('restarting resets the timer for the first card', () async {
    final clock = FixedClock(_now);
    final c = makeContainer(clock: clock);
    final deck = await _deck(c, 'A');
    await _card(c, deck, 'A');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);
    clock.advance(const Duration(minutes: 3));
    notifier.restart();
    clock.advance(const Duration(seconds: 2));

    await notifier.rate(Rating.good);

    final logs = await c.read(reviewLogRepositoryProvider).watchAll().first;
    expect(logs.single.elapsedMs, 2000);
  });

  test('skipping a deleted card resets the timer without logging it', () async {
    final clock = FixedClock(_now);
    final c = makeContainer(clock: clock);
    final deck = await _deck(c, 'A');
    final a = await _card(c, deck, 'A');
    final b = await _card(c, deck, 'B');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);
    await notifier.start(cardIds: [a, b]);
    clock.advance(const Duration(seconds: 20));
    await c.read(cardCommandsProvider).deleteCard(a);
    notifier.skip();
    clock.advance(const Duration(seconds: 3));

    await notifier.rate(Rating.good);

    final logs = await c.read(reviewLogRepositoryProvider).watchAll().first;
    expect(logs, hasLength(1));
    expect(logs.single.cardId, b);
    expect(logs.single.elapsedMs, 3000);
  });
}
