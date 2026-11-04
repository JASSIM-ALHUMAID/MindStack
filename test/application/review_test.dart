import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/inbox.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/review.dart';
import 'package:mindstack/data/drift_transaction_runner.dart';
import 'package:mindstack/data/repositories/drift_card_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/deck_stats.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/repositories.dart';

import '../support/container.dart';
import '../support/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

Future<String> _deck(ProviderContainer c, [String title = 'Deck']) async {
  final library = c.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course $title',
    examDate: DateTime(2026, 12, 1),
  );
  return library.createDeck(courseId: course, title: title);
}

Future<String> _card(
  ProviderContainer c,
  String deck, {
  required String question,
  DateTime? dueAt,
  double mastery = 0,
}) async {
  final id = await c
      .read(cardCommandsProvider)
      .addCard(deckId: deck, question: question, answer: 'A');
  if (dueAt != null || mastery != 0) {
    final repo = c.read(cardRepositoryProvider);
    final card = await repo.byId(id);
    await repo.update(card.copyWith(dueAt: dueAt, mastery: mastery));
  }
  return id;
}

/// Runs actions through [_inner] only after [gate] completes.
final class _GatedRunner implements TransactionRunner {
  _GatedRunner(this._inner, {this.gate});

  final TransactionRunner _inner;
  final Future<void>? gate;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    await gate;
    return _inner.run(action);
  }
}

/// A [CardRepository] whose `watchByDeck` stream waits for [gate] before it
/// emits; everything else is delegated.
final class _GatedDeckCards implements CardRepository {
  _GatedDeckCards(this._inner, this.gate);

  final CardRepository _inner;
  final Future<void> gate;

  @override
  Stream<List<Flashcard>> watchByDeck(String deckId) async* {
    await gate;
    yield* _inner.watchByDeck(deckId);
  }

  @override
  Stream<List<Flashcard>> watchAll() => _inner.watchAll();

  @override
  Stream<Map<String, DeckStats>> watchDeckStats() => _inner.watchDeckStats();

  @override
  Future<List<Flashcard>> due({required DateTime now, String? deckId}) =>
      _inner.due(now: now, deckId: deckId);

  @override
  Future<Flashcard> byId(String id) => _inner.byId(id);

  @override
  Future<void> insert(Flashcard card) => _inner.insert(card);

  @override
  Future<void> insertAll(List<Flashcard> cards) => _inner.insertAll(cards);

  @override
  Future<void> update(Flashcard card) => _inner.update(card);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<int> moveToDeck({
    required String fromDeckId,
    required String toDeckId,
  }) => _inner.moveToDeck(fromDeckId: fromDeckId, toDeckId: toDeckId);
}

void main() {
  test('inbox ocrProgressProvider defaults to null', () {
    final c = makeContainer();
    expect(c.read(ocrProgressProvider), isNull);
  });

  test('queue contains only due cards', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final due = await _card(c, deck, question: 'due');
    await _card(
      c,
      deck,
      question: 'later',
      dueAt: _now.add(const Duration(days: 3)),
    );

    final state = await c.read(reviewProvider.future);

    expect(state.cardIds, [due]);
    expect(state.index, 0);
    expect(state.saving, isFalse);
  });

  test('rate advances and persists', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final id = await _card(c, deck, question: 'q');
    await c.read(reviewProvider.future);

    await c.read(reviewProvider.notifier).rate(Rating.good);

    final state = c.read(reviewProvider).requireValue;
    expect(state.index, 1);
    expect(state.finished, isTrue);
    expect(state.saving, isFalse);
    final stored = await c.read(cardRepositoryProvider).byId(id);
    expect(stored.repetitions, 1);
  });

  test('rating twice quickly rates the card once', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final first = await _card(c, deck, question: 'one');
    await _card(c, deck, question: 'two');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);

    final a = notifier.rate(Rating.good);
    final b = notifier.rate(Rating.good);
    await Future.wait([a, b]);

    expect(c.read(reviewProvider).requireValue.index, 1);
    final stored = await c.read(cardRepositoryProvider).byId(first);
    expect(stored.repetitions, 1);
  });

  test('skip advances past a deleted card', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final gone = await _card(c, deck, question: 'gone');
    await _card(c, deck, question: 'kept');
    await c.read(reviewProvider.future);
    await c.read(cardCommandsProvider).deleteCard(gone);

    c.read(reviewProvider.notifier).skip();

    final state = c.read(reviewProvider).requireValue;
    expect(state.index, 1);
    expect(state.saving, isFalse);
  });

  test('rate does nothing once the session is finished', () async {
    final c = makeContainer(clock: FixedClock(_now));
    await c.read(reviewProvider.future);

    await c.read(reviewProvider.notifier).rate(Rating.good);

    expect(c.read(reviewProvider).requireValue.index, 0);
  });

  test('failed rate keeps the index and rethrows the AppFailure', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final id = await _card(c, deck, question: 'q');
    await c.read(reviewProvider.future);
    await c.read(cardCommandsProvider).deleteCard(id);

    await expectLater(
      c.read(reviewProvider.notifier).rate(Rating.good),
      throwsA(isA<NotFound>()),
    );

    final state = c.read(reviewProvider);
    expect(state.hasError, isFalse);
    expect(state.requireValue.index, 0);
    expect(state.requireValue.saving, isFalse);
  });

  test('restart returns to the first card', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    await _card(c, deck, question: 'q');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);
    await notifier.rate(Rating.good);

    notifier.restart();

    expect(c.read(reviewProvider).requireValue.index, 0);
  });

  test('startDeck queues only that deck', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final a = await _deck(c, 'A');
    final b = await _deck(c, 'B');
    final inA = await _card(
      c,
      a,
      question: 'a',
      dueAt: _now.add(const Duration(days: 9)),
    );
    await _card(c, b, question: 'b');
    await c.read(reviewProvider.future);

    await c.read(reviewProvider.notifier).startDeck(a);

    final state = c.read(reviewProvider).requireValue;
    expect(state.cardIds, [inA]);
    expect(state.index, 0);
  });

  test('startWeak picks the lowest mastery cards', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final high = await _card(c, deck, question: 'h', mastery: 0.9);
    final low = await _card(c, deck, question: 'l', mastery: 0.1);
    final mid = await _card(c, deck, question: 'm', mastery: 0.5);
    final top = await _card(c, deck, question: 't', mastery: 1);
    await c.read(reviewProvider.future);

    await c.read(reviewProvider.notifier).startWeak(count: 3);

    final ids = c.read(reviewProvider).requireValue.cardIds;
    expect(ids, [low, mid, high]);
    expect(ids, isNot(contains(top)));
  });

  test('current card reflects a live edit', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final id = await _card(c, deck, question: 'old');
    await c.read(reviewProvider.future);
    await c.read(allCardsProvider.future);
    final seen = <String?>[];
    c.listen(
      currentReviewCardProvider,
      (_, next) => seen.add(next.value?.question),
      fireImmediately: true,
    );

    final repo = c.read(cardRepositoryProvider);
    await repo.update((await repo.byId(id)).copyWith(question: 'new'));
    await pumpEventQueue();

    expect(seen.last, 'new');
  });

  test('current card is null when finished or deleted', () async {
    final c = makeContainer(clock: FixedClock(_now));
    final deck = await _deck(c);
    final id = await _card(c, deck, question: 'q');
    await c.read(reviewProvider.future);
    await c.read(allCardsProvider.future);
    final sub = c.listen(currentReviewCardProvider, (_, _) {});
    expect(sub.read().value, isA<Flashcard>());

    await c.read(cardCommandsProvider).deleteCard(id);
    await pumpEventQueue();

    expect(sub.read(), const AsyncData<Flashcard?>(null));
  });

  test('a stale rating does not clobber a newly started queue', () async {
    final gate = Completer<void>();
    final c = makeContainer(
      clock: FixedClock(_now),
      overrides: [
        transactionRunnerProvider.overrideWith(
          (ref) => _GatedRunner(
            DriftTransactionRunner(ref.watch(databaseProvider)),
            gate: gate.future,
          ),
        ),
      ],
    );
    final a = await _deck(c, 'A');
    final b = await _deck(c, 'B');
    await _card(c, a, question: 'a');
    final inB = await _card(c, b, question: 'b1');
    await _card(c, b, question: 'b2');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);

    final pending = notifier.rate(Rating.good);
    await notifier.startDeck(b);
    gate.complete();
    await pending;

    final state = c.read(reviewProvider).requireValue;
    expect(state.index, 0);
    expect(state.saving, isFalse);
    expect(state.cardIds, hasLength(2));
    expect(state.cardIds, contains(inB));
  });

  test(
    'a non-AppFailure error releases saving and a later rate works',
    () async {
      var fail = true;
      final c = makeContainer(
        clock: FixedClock(_now),
        overrides: [
          transactionRunnerProvider.overrideWith((ref) {
            final real = DriftTransactionRunner(ref.watch(databaseProvider));
            return _SwitchRunner(real, () => fail);
          }),
        ],
      );
      final deck = await _deck(c);
      final id = await _card(c, deck, question: 'q');
      await c.read(reviewProvider.future);
      final notifier = c.read(reviewProvider.notifier);

      await expectLater(notifier.rate(Rating.good), throwsStateError);
      expect(c.read(reviewProvider).requireValue.saving, isFalse);
      expect(c.read(reviewProvider).requireValue.index, 0);

      fail = false;
      await notifier.rate(Rating.good);
      expect(c.read(reviewProvider).requireValue.index, 1);
      expect((await c.read(cardRepositoryProvider).byId(id)).repetitions, 1);
    },
  );

  test('the newer start wins when an older one finishes last', () async {
    final slow = Completer<void>();
    late String deckA;
    final c = makeContainer(
      clock: FixedClock(_now),
      overrides: [
        cardRepositoryProvider.overrideWith(
          (ref) => _GatedDeckCards(
            DriftCardRepository(ref.watch(databaseProvider)),
            slow.future,
          ),
        ),
      ],
    );
    deckA = await _deck(c, 'A');
    await _card(c, deckA, question: 'in A', mastery: 0.5);
    final deckB = await _deck(c, 'B');
    final weak = await _card(c, deckB, question: 'in B');
    await c.read(reviewProvider.future);
    final notifier = c.read(reviewProvider.notifier);

    final older = notifier.startDeck(deckA);
    await notifier.startWeak(count: 1);
    final newer = c.read(reviewProvider).requireValue.cardIds;
    slow.complete();
    await older;

    expect(c.read(reviewProvider).requireValue.cardIds, newer);
    expect(newer, [weak]);
  });
}

final class _SwitchRunner implements TransactionRunner {
  _SwitchRunner(this._inner, this._shouldFail);

  final TransactionRunner _inner;
  final bool Function() _shouldFail;

  @override
  Future<T> run<T>(Future<T> Function() action) {
    if (_shouldFail()) throw StateError('boom');
    return _inner.run(action);
  }
}
