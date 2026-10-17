import 'dart:math' as math;

/// Where a card came from. `shared` means it was imported from a deck file.
enum CardSource { manual, slide, pdf, photo, shared }

/// The four recall buttons on the Review screen.
enum Rating { again, hard, good, easy }

class Flashcard {
  final String id;
  final String deckId;
  final String question;
  final String answer;
  final CardSource source;

  /// Example: "Page 2", "Lecture 1", "Whiteboard #1".
  final String? sourceRef;

  // Spaced-repetition fields (SM-2 style).
  final int intervalDays;
  final double ease;
  final int repetitions;
  final DateTime dueAt;

  /// 0.0 to 1.0, shown as a percentage in the Deck Editor and Stats.
  final double mastery;

  const Flashcard({
    required this.id,
    required this.deckId,
    required this.question,
    required this.answer,
    this.source = CardSource.manual,
    this.sourceRef,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.repetitions = 0,
    required this.dueAt,
    this.mastery = 0,
  });

  bool get isNew => repetitions == 0;

  Flashcard copyWith({
    String? deckId,
    String? question,
    String? answer,
    int? intervalDays,
    double? ease,
    int? repetitions,
    DateTime? dueAt,
    double? mastery,
  }) {
    return Flashcard(
      id: id,
      deckId: deckId ?? this.deckId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      source: source,
      sourceRef: sourceRef,
      intervalDays: intervalDays ?? this.intervalDays,
      ease: ease ?? this.ease,
      repetitions: repetitions ?? this.repetitions,
      dueAt: dueAt ?? this.dueAt,
      mastery: mastery ?? this.mastery,
    );
  }

  /// Returns the card after the user rated it. Simplified SM-2 scheduling.
  Flashcard applyRating(Rating rating, {DateTime? now}) {
    final t = now ?? DateTime.now();
    var newEase = ease;
    var newReps = repetitions;
    var newInterval = intervalDays;
    var newMastery = mastery;

    switch (rating) {
      case Rating.again:
        newReps = 0;
        newInterval = 0;
        newEase = math.max(1.3, ease - 0.2);
        newMastery -= 0.20;
        break;
      case Rating.hard:
        newReps += 1;
        newInterval = math.max(1, (intervalDays * 1.2).round());
        newEase = math.max(1.3, ease - 0.15);
        newMastery -= 0.05;
        break;
      case Rating.good:
        newInterval = repetitions == 0
            ? 1
            : (repetitions == 1 ? 3 : (intervalDays * ease).round());
        newReps += 1;
        newMastery += 0.10;
        break;
      case Rating.easy:
        newInterval = math.max(4, (math.max(1, intervalDays) * ease * 1.3).round());
        newReps += 1;
        newEase = ease + 0.15;
        newMastery += 0.15;
        break;
    }

    final due = rating == Rating.again
        ? t.add(const Duration(minutes: 10))
        : t.add(Duration(days: newInterval));

    return copyWith(
      intervalDays: newInterval,
      ease: newEase,
      repetitions: newReps,
      dueAt: due,
      mastery: newMastery.clamp(0.0, 1.0).toDouble(),
    );
  }
}
