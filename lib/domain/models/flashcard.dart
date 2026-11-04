import '../enums.dart';

/// A question/answer card with its spaced-repetition state.
class Flashcard {
  /// Creates a card. Scheduling fields default to a brand-new card.
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

  /// Stable unique id.
  final String id;

  /// Id of the deck this card belongs to.
  final String deckId;

  /// Front of the card.
  final String question;

  /// Back of the card.
  final String answer;

  /// How the card was created.
  final CardSource source;

  /// Example: "Page 2", "Lecture 1", "Whiteboard #1".
  final String? sourceRef;

  // Spaced-repetition fields (SM-2 style).
  /// Days until the next review after the last rating.
  final int intervalDays;

  /// SM-2 ease factor; never below 1.3.
  final double ease;

  /// Consecutive successful reviews (0 for a new card).
  final int repetitions;

  /// When the card is next due for review.
  final DateTime dueAt;

  /// 0.0 to 1.0, shown as a percentage in the Deck Editor and Stats.
  final double mastery;

  /// Whether the card has never been reviewed successfully.
  bool get isNew => repetitions == 0;

  /// A copy with the given fields replaced. `id`, `source` and `sourceRef`
  /// never change.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flashcard &&
          other.id == id &&
          other.deckId == deckId &&
          other.question == question &&
          other.answer == answer &&
          other.source == source &&
          other.sourceRef == sourceRef &&
          other.intervalDays == intervalDays &&
          other.ease == ease &&
          other.repetitions == repetitions &&
          other.dueAt == dueAt &&
          other.mastery == mastery;

  @override
  int get hashCode => Object.hash(
    id,
    deckId,
    question,
    answer,
    source,
    sourceRef,
    intervalDays,
    ease,
    repetitions,
    dueAt,
    mastery,
  );

  @override
  String toString() =>
      'Flashcard(id: $id, deckId: $deckId, '
      'question: $question, answer: $answer, source: ${source.name}, '
      'sourceRef: $sourceRef, intervalDays: $intervalDays, ease: $ease, '
      'repetitions: $repetitions, dueAt: $dueAt, mastery: $mastery)';
}
