import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/data/repositories/drift_review_log_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/review_log.dart';
import 'package:mindstack/domain/repositories.dart';

import '../support/container.dart';
import '../support/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

Future<String> _newCard(ProviderContainer container) async {
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  final deck = await library.createDeck(courseId: course, title: 'Deck');
  return container
      .read(cardCommandsProvider)
      .addCard(deckId: deck, question: 'Question?', answer: 'Answer.');
}

/// Fails after a real insert to verify rollback of both database writes.
final class _FailAfterInsert implements ReviewLogRepository {
  const _FailAfterInsert(this.inner);

  final ReviewLogRepository inner;

  @override
  Stream<List<ReviewLog>> watchAll() => inner.watchAll();

  @override
  Future<List<ReviewLog>> byCard(String cardId) => inner.byCard(cardId);

  @override
  Future<void> insert(ReviewLog log) async {
    await inner.insert(log);
    throw StorageFailure(
      StateError('Simulated write failure'),
      StackTrace.current,
    );
  }
}

void main() {
  test('good rating persists schedule and exactly one review log', () async {
    final container = makeContainer(clock: FixedClock(_now));
    final id = await _newCard(container);

    final rated = await container
        .read(cardCommandsProvider)
        .rateCard(id, Rating.good, elapsedMs: 2500);

    final stored = await container.read(cardRepositoryProvider).byId(id);
    expect(stored, rated);
    expect(stored.intervalDays, 1);
    expect(stored.repetitions, 1);
    expect(stored.dueAt, _now.add(const Duration(days: 1)));
    final logs = await container
        .read(reviewLogRepositoryProvider)
        .watchAll()
        .first;
    expect(logs, hasLength(1));
    expect(logs.single.cardId, id);
    expect(logs.single.rating, Rating.good);
    expect(logs.single.reviewedAt, _now);
    expect(logs.single.elapsedMs, 2500);
  });

  test(
    'existing callers record zero elapsed time until timing is wired',
    () async {
      final container = makeContainer();
      final id = await _newCard(container);
      await container.read(cardCommandsProvider).rateCard(id, Rating.hard);

      final logs = await container
          .read(reviewLogRepositoryProvider)
          .watchAll()
          .first;
      expect(logs.single.elapsedMs, 0);
      expect(logs.single.rating, Rating.hard);
    },
  );

  test('failed log write rolls back the schedule and inserted log', () async {
    final container = makeContainer(
      overrides: [
        reviewLogRepositoryProvider.overrideWith(
          (ref) => _FailAfterInsert(
            DriftReviewLogRepository(ref.watch(databaseProvider)),
          ),
        ),
      ],
    );
    final id = await _newCard(container);
    final cards = container.read(cardRepositoryProvider);
    final before = await cards.byId(id);

    await expectLater(
      container
          .read(cardCommandsProvider)
          .rateCard(id, Rating.good, elapsedMs: 1500),
      throwsA(isA<StorageFailure>()),
    );

    expect(await cards.byId(id), before);
    expect(
      await container.read(reviewLogRepositoryProvider).watchAll().first,
      isEmpty,
    );
  });

  test('negative elapsed time is rejected without writing', () async {
    final container = makeContainer();
    final id = await _newCard(container);
    final cards = container.read(cardRepositoryProvider);
    final before = await cards.byId(id);

    await expectLater(
      container
          .read(cardCommandsProvider)
          .rateCard(id, Rating.good, elapsedMs: -1),
      throwsA(isA<InvalidInput>()),
    );

    expect(await cards.byId(id), before);
    expect(
      await container.read(reviewLogRepositoryProvider).watchAll().first,
      isEmpty,
    );
  });

  test('missing card does not create a review log', () async {
    final container = makeContainer();
    await expectLater(
      container.read(cardCommandsProvider).rateCard('missing', Rating.good),
      throwsA(isA<NotFound>()),
    );
    expect(
      await container.read(reviewLogRepositoryProvider).watchAll().first,
      isEmpty,
    );
  });
}
