import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/quiz.dart';
import 'package:mindstack/domain/enums.dart';

import '../support/container.dart';
import '../support/fakes.dart';

final _now = DateTime(2026, 11, 4, 12);

ProviderContainer _container({FixedClock? clock}) => makeContainer(
  clock: clock ?? FixedClock(_now),
  overrides: [quizRandomProvider.overrideWithValue(Random(1))],
);

/// Adds a deck with [count] cards Q1/A1, Q2/A2, ... (`Q${prefix}1` with a
/// [prefix]); returns the card ids.
Future<List<String>> _cards(
  ProviderContainer container,
  int count, {
  String prefix = '',
}) async {
  final library = container.read(libraryCommandsProvider);
  final course = await library.createCourse(
    title: 'Course',
    examDate: DateTime(2026, 12, 1),
  );
  final deck = await library.createDeck(courseId: course, title: 'Deck');
  final cards = container.read(cardCommandsProvider);
  return [
    for (var i = 1; i <= count; i++)
      await cards.addCard(
        deckId: deck,
        question: 'Q$prefix$i',
        answer: 'A$prefix$i',
      ),
  ];
}

void main() {
  test('the quiz is built from the stored cards', () async {
    final container = _container();
    final ids = await _cards(container, 6);

    final quiz = await container.read(quizProvider.future);

    expect(quiz.questions, hasLength(5));
    for (final q in quiz.questions) {
      expect(ids, contains(q.id));
      final n = q.prompt.substring(1);
      expect(q.options[q.correctIndex], 'A$n');
    }
  });

  test('fewer than 4 cards gives an empty quiz', () async {
    final container = _container();
    await _cards(container, 3);

    final quiz = await container.read(quizProvider.future);

    expect(quiz.questions, isEmpty);
    expect(quiz.finished, isTrue);
  });

  test(
    'missed answer writes a Rating.again log and makes the card due',
    () async {
      final clock = FixedClock(_now);
      final container = _container(clock: clock);
      await _cards(container, 4);
      final quiz = await container.read(quizProvider.future);
      final question = quiz.current!;
      final wrong = (question.correctIndex + 1) % question.options.length;
      clock.advance(const Duration(seconds: 3));

      await container.read(quizProvider.notifier).select(wrong);

      final logs = await container
          .read(reviewLogRepositoryProvider)
          .watchAll()
          .first;
      expect(logs, hasLength(1));
      expect(logs.single.cardId, question.id);
      expect(logs.single.rating, Rating.again);
      expect(logs.single.elapsedMs, 3000);
      final card = await container
          .read(cardRepositoryProvider)
          .byId(question.id);
      expect(card.repetitions, 0);
      expect(card.dueAt, clock.now().add(const Duration(minutes: 10)));

      final state = container.read(quizProvider).requireValue;
      expect(state.score, 0);
      expect(state.missedCardIds, [question.id]);
      expect(state.secondsPerQuestion, 3);
    },
  );

  test('a correct answer scores and writes no log', () async {
    final container = _container();
    await _cards(container, 4);
    final quiz = await container.read(quizProvider.future);

    await container
        .read(quizProvider.notifier)
        .select(quiz.current!.correctIndex);

    expect(container.read(quizProvider).requireValue.score, 1);
    expect(
      await container.read(reviewLogRepositoryProvider).watchAll().first,
      isEmpty,
    );
  });

  test('a second tap on the same question is ignored', () async {
    final container = _container();
    await _cards(container, 4);
    final quiz = await container.read(quizProvider.future);
    final notifier = container.read(quizProvider.notifier);
    final right = quiz.current!.correctIndex;

    await notifier.select((right + 1) % 4);
    await notifier.select(right);

    final state = container.read(quizProvider).requireValue;
    expect(state.score, 0);
    expect(state.missed, [0]);
  });

  test('answering every question reaches the results', () async {
    final container = _container();
    await _cards(container, 4);
    final notifier = container.read(quizProvider.notifier);
    final total = (await container.read(quizProvider.future)).questions.length;

    for (var i = 0; i < total; i++) {
      final q = container.read(quizProvider).requireValue.current!;
      await notifier.select(q.correctIndex);
      notifier.next();
    }

    final state = container.read(quizProvider).requireValue;
    expect(state.finished, isTrue);
    expect(state.score, total);
    expect(state.missedCardIds, isEmpty);
  });

  test('refreshIfIdle picks up cards added after the empty quiz', () async {
    final container = _container();
    await _cards(container, 3);
    expect((await container.read(quizProvider.future)).questions, isEmpty);

    await _cards(container, 2, prefix: 'new');
    container.read(quizProvider.notifier).refreshIfIdle();

    expect((await container.read(quizProvider.future)).questions, isNotEmpty);
  });

  test('refreshIfIdle keeps a quiz in progress', () async {
    final container = _container();
    await _cards(container, 4);
    final quiz = await container.read(quizProvider.future);
    await container
        .read(quizProvider.notifier)
        .select(quiz.current!.correctIndex);

    container.read(quizProvider.notifier).refreshIfIdle();

    final state = container.read(quizProvider);
    expect(state.isLoading, isFalse);
    expect(state.requireValue.score, 1);
  });
}
