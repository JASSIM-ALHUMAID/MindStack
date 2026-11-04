import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/scheduler.dart';

void main() {
  final now = DateTime(2026, 1, 10, 9);

  Flashcard card({
    double ease = 2.5,
    int repetitions = 0,
    int intervalDays = 0,
    double mastery = 0.5,
  }) {
    return Flashcard(
      id: 'c1',
      deckId: 'd1',
      question: 'Q',
      answer: 'A',
      dueAt: now,
      ease: ease,
      repetitions: repetitions,
      intervalDays: intervalDays,
      mastery: mastery,
    );
  }

  test('again resets progress and is due in 10 minutes', () {
    final result = Sm2Scheduler.apply(card(), Rating.again, now: now);
    expect(result.intervalDays, 0);
    expect(result.repetitions, 0);
    expect(result.ease, closeTo(2.3, 1e-9));
    expect(result.dueAt, now.add(const Duration(minutes: 10)));
    expect(result.mastery, closeTo(0.3, 1e-9));
  });

  test('good on a new card is due in one day', () {
    final result = Sm2Scheduler.apply(card(), Rating.good, now: now);
    expect(result.intervalDays, 1);
    expect(result.repetitions, 1);
    expect(result.dueAt, now.add(const Duration(days: 1)));
  });

  test('good on the second repetition gives 3 days', () {
    final result = Sm2Scheduler.apply(
      card(repetitions: 1, intervalDays: 1),
      Rating.good,
      now: now,
    );
    expect(result.intervalDays, 3);
  });

  test('good later multiplies the interval by ease and rounds', () {
    final result = Sm2Scheduler.apply(
      card(repetitions: 2, intervalDays: 3),
      Rating.good,
      now: now,
    );
    expect(result.intervalDays, 8);
  });

  test('easy on a new card gives 4 days and raises ease', () {
    final result = Sm2Scheduler.apply(card(), Rating.easy, now: now);
    expect(result.intervalDays, 4);
    expect(result.ease, closeTo(2.65, 1e-9));
  });

  test('hard never drops ease below 1.3', () {
    final result = Sm2Scheduler.apply(card(ease: 1.35), Rating.hard, now: now);
    expect(result.ease, 1.3);
  });

  test('mastery is clamped to 1.0', () {
    final result = Sm2Scheduler.apply(
      card(mastery: 0.95),
      Rating.easy,
      now: now,
    );
    expect(result.mastery, 1.0);
  });

  test('mastery is clamped to 0.0', () {
    final result = Sm2Scheduler.apply(
      card(mastery: 0.1),
      Rating.again,
      now: now,
    );
    expect(result.mastery, 0.0);
  });
}
