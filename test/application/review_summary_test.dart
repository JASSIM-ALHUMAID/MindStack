import 'dart:async';

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

Future<List<String>> _cards(ProviderContainer c) async {
  final library = c.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  final deck = await library.createDeck(courseId: course, title: 'Deck');
  final commands = c.read(cardCommandsProvider);
  return [
    await commands.addCard(deckId: deck, question: 'A', answer: 'Answer A'),
    await commands.addCard(deckId: deck, question: 'B', answer: 'Answer B'),
  ];
}

final class _ControlledRunner implements TransactionRunner {
  _ControlledRunner(this.inner);

  final TransactionRunner inner;
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    await gate?.future;
    if (fail) throw StateError('Simulated failure');
    return inner.run(action);
  }
}

void main() {
  test('summary uses only the exact logs committed by this session', () async {
    final clock = FixedClock(_now);
    final c = makeContainer(clock: clock);
    final ids = await _cards(c);
    await c
        .read(cardCommandsProvider)
        .rateCard(ids.first, Rating.good, elapsedMs: 9000);
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);
    await notifier.start(cardIds: ids);

    clock.advance(const Duration(seconds: 2));
    await notifier.rate(Rating.good);
    clock.advance(const Duration(seconds: 5));
    await notifier.rate(Rating.easy);

    final summary = c.read(reviewProvider).requireValue;
    final logs = await c.read(reviewLogRepositoryProvider).watchAll().first;
    expect(summary.finished, isTrue);
    expect(logs, hasLength(3));
    expect(summary.results.map((result) => result.log), logs.skip(1));
    expect(summary.reviewedCount, 2);
    expect(summary.elapsedMs, 7000);
    expect(summary.secondsPerCard, 3.5);
    final first = await c.read(cardRepositoryProvider).byId(ids.first);
    expect(summary.nextDue, first.dueAt);
  });

  test(
    'skipped cards are excluded from the count, timing and due date',
    () async {
      final clock = FixedClock(_now);
      final c = makeContainer(clock: clock);
      final ids = await _cards(c);
      await c.read(reviewProvider.future);
      final notifier = c.read(reviewProvider.notifier);
      await notifier.start(cardIds: ids);
      await c.read(cardCommandsProvider).deleteCard(ids.first);
      clock.advance(const Duration(seconds: 30));
      notifier.skip();
      clock.advance(const Duration(seconds: 4));
      await notifier.rate(Rating.good);

      final summary = c.read(reviewProvider).requireValue;
      expect(summary.finished, isTrue);
      expect(summary.reviewedCount, 1);
      expect(summary.elapsedMs, 4000);
      expect(summary.secondsPerCard, 4);
      expect(summary.results.single.log.cardId, ids.last);
    },
  );

  test('a failed save adds no result and retry adds exactly one', () async {
    late _ControlledRunner runner;
    final c = makeContainer(
      overrides: [
        transactionRunnerProvider.overrideWith((ref) {
          runner = _ControlledRunner(
            DriftTransactionRunner(ref.watch(databaseProvider)),
          );
          return runner;
        }),
      ],
    );
    final ids = await _cards(c);
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);
    await notifier.start(cardIds: [ids.first]);
    // Resolve the override before changing its failure switch.
    c.read(transactionRunnerProvider);
    runner.fail = true;

    await expectLater(notifier.rate(Rating.good), throwsStateError);
    expect(c.read(reviewProvider).requireValue.results, isEmpty);
    expect(c.read(reviewProvider).requireValue.index, 0);

    runner.fail = false;
    await notifier.rate(Rating.good);
    expect(c.read(reviewProvider).requireValue.reviewedCount, 1);
    expect(
      await c.read(reviewLogRepositoryProvider).watchAll().first,
      hasLength(1),
    );
  });

  test(
    'restart and a new start clear session totals but retain stored logs',
    () async {
      final c = makeContainer();
      final ids = await _cards(c);
      await c.read(reviewProvider.future);
      final notifier = c.read(reviewProvider.notifier);
      await notifier.start(cardIds: [ids.first]);
      await notifier.rate(Rating.good);
      final previousSession = c.read(reviewProvider).requireValue.sessionId;

      notifier.restart();
      var state = c.read(reviewProvider).requireValue;
      expect(state.results, isEmpty);
      expect(state.sessionId, isNot(previousSession));
      await notifier.rate(Rating.good);
      await notifier.start(cardIds: [ids.last]);

      state = c.read(reviewProvider).requireValue;
      expect(state.reviewedCount, 0);
      expect(state.elapsedMs, 0);
      expect(state.secondsPerCard, 0);
      expect(state.nextDue, isNull);
      expect(
        await c.read(reviewLogRepositoryProvider).watchAll().first,
        hasLength(2),
      );
    },
  );

  test(
    'later card changes do not rewrite the completed session result',
    () async {
      final c = makeContainer();
      final ids = await _cards(c);
      await c.read(reviewProvider.future);
      final notifier = c.read(reviewProvider.notifier);
      await notifier.start(cardIds: [ids.first]);
      await notifier.rate(Rating.good);
      final due = c.read(reviewProvider).requireValue.nextDue;
      final cards = c.read(cardRepositoryProvider);
      await cards.update(
        (await cards.byId(ids.first))
            .copyWith(dueAt: _now.add(const Duration(days: 100))),
      );

      expect(c.read(reviewProvider).requireValue.nextDue, due);
    },
  );

  test(
    'an older in-flight rating cannot enter a new session summary',
    () async {
      late _ControlledRunner runner;
      final c = makeContainer(
        overrides: [
          transactionRunnerProvider.overrideWith((ref) {
            runner = _ControlledRunner(
              DriftTransactionRunner(ref.watch(databaseProvider)),
            );
            return runner;
          }),
        ],
      );
      final ids = await _cards(c);
      await c.read(reviewProvider.future);
      final notifier = c.read(reviewProvider.notifier);
      await notifier.start(cardIds: [ids.first]);
      c.read(transactionRunnerProvider);
      final gate = Completer<void>();
      runner.gate = gate;
      final pending = notifier.rate(Rating.good);

      await notifier.start(cardIds: [ids.last]);
      gate.complete();
      await pending;

      final current = c.read(reviewProvider).requireValue;
      expect(current.cardIds, [ids.last]);
      expect(current.results, isEmpty);
      expect(current.index, 0);
      expect(
        await c.read(reviewLogRepositoryProvider).watchAll().first,
        hasLength(1),
      );
    },
  );
}
