import 'flashcard.dart';

/// One rated review. Used later for the streak, session pace and weak cards.
class ReviewLog {
  final String id;
  final String cardId;
  final DateTime reviewedAt;
  final Rating rating;
  final int elapsedMs;

  const ReviewLog({
    required this.id,
    required this.cardId,
    required this.reviewedAt,
    required this.rating,
    required this.elapsedMs,
  });
}
