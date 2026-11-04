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

  final String id;
  final String cardId;
  final DateTime reviewedAt;
  final Rating rating;
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
