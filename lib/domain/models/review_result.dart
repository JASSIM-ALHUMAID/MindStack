import 'flashcard.dart';
import 'review_log.dart';

/// Receipt for one committed rating. The card is a historical snapshot of
/// its schedule immediately after rating, not a replacement for live data.
class ReviewResult {
  const ReviewResult({required this.card, required this.log});

  final Flashcard card;
  final ReviewLog log;

  @override
  bool operator ==(Object other) =>
      other is ReviewResult && other.card == card && other.log == log;

  @override
  int get hashCode => Object.hash(card, log);
}
