import 'dart:math' as math;

import 'enums.dart';
import 'models/flashcard.dart';

/// Simplified SM-2 spaced-repetition scheduling.
abstract final class Sm2Scheduler {
  /// Returns [card] after the user rated it [rating] at [now].
  static Flashcard apply(
    Flashcard card,
    Rating rating, {
    required DateTime now,
  }) {
    var newEase = card.ease;
    var newReps = card.repetitions;
    var newInterval = card.intervalDays;
    var newMastery = card.mastery;

    switch (rating) {
      case Rating.again:
        newReps = 0;
        newInterval = 0;
        newEase = math.max(1.3, card.ease - 0.2);
        newMastery -= 0.20;
      case Rating.hard:
        newReps += 1;
        newInterval = math.max(1, (card.intervalDays * 1.2).round());
        newEase = math.max(1.3, card.ease - 0.15);
        newMastery -= 0.05;
      case Rating.good:
        newInterval = card.repetitions == 0
            ? 1
            : (card.repetitions == 1
                  ? 3
                  : (card.intervalDays * card.ease).round());
        newReps += 1;
        newMastery += 0.10;
      case Rating.easy:
        newInterval = math.max(
          4,
          (math.max(1, card.intervalDays) * card.ease * 1.3).round(),
        );
        newReps += 1;
        newEase = card.ease + 0.15;
        newMastery += 0.15;
    }

    final due = rating == Rating.again
        ? now.add(const Duration(minutes: 10))
        : now.add(Duration(days: newInterval));

    return card.copyWith(
      intervalDays: newInterval,
      ease: newEase,
      repetitions: newReps,
      dueAt: due,
      mastery: newMastery.clamp(0.0, 1.0).toDouble(),
    );
  }
}
