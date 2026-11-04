import '../enums.dart';

/// One rated review. Used later for the streak, session pace and weak cards.
class ReviewLog {
  /// Creates a log entry.
  const ReviewLog({
    required this.id,
    required this.cardId,
    required this.reviewedAt,
    required this.rating,
    required this.elapsedMs,
  });

  /// Stable unique id.
  final String id;

  /// Id of the card that was rated.
  final String cardId;

  /// When the rating was made.
  final DateTime reviewedAt;

  /// The rating the user chose.
  final Rating rating;

  /// Time spent on the card before rating, in milliseconds.
  final int elapsedMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewLog &&
          other.id == id &&
          other.cardId == cardId &&
          other.reviewedAt == reviewedAt &&
          other.rating == rating &&
          other.elapsedMs == elapsedMs;

  @override
  int get hashCode => Object.hash(id, cardId, reviewedAt, rating, elapsedMs);

  @override
  String toString() =>
      'ReviewLog(id: $id, cardId: $cardId, '
      'reviewedAt: $reviewedAt, rating: ${rating.name}, '
      'elapsedMs: $elapsedMs)';
}
