import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/flashcard.dart';
import '../domain/models/review_log.dart';
import '../domain/streak.dart';
import 'cards.dart';
import 'core_providers.dart';
import 'library.dart';
import 'services.dart';

/// Live list of every review log, oldest first.
final reviewLogsProvider = StreamProvider<List<ReviewLog>>(
  (ref) => ref.watch(reviewLogRepositoryProvider).watchAll(),
);

/// The study streak, computed from the review logs as of now.
final streakProvider = Provider<AsyncValue<StreakInfo>>(
  (ref) => ref
      .watch(reviewLogsProvider)
      .whenData(
        (logs) => computeStreak([
          for (final log in logs) log.reviewedAt,
        ], ref.read(clockProvider).now()),
      ),
);

/// How many weakest cards Stats lists and drills.
const int kWeakestCardCount = 3;

/// The reviewed cards with the lowest mastery, weakest first, at most
/// [kWeakestCardCount]. Cards never reviewed are left out: their mastery is
/// 0 only because nothing is known about them yet.
final weakestCardsProvider = Provider<AsyncValue<List<Flashcard>>>((ref) {
  final cards = ref.watch(allCardsProvider);
  final logs = ref.watch(reviewLogsProvider);
  return _combine(cards, logs, (cards, logs) {
    final reviewed = {for (final log in logs) log.cardId};
    final weakest = [
      for (final card in cards)
        if (reviewed.contains(card.id)) card,
    ]..sort((a, b) => a.mastery.compareTo(b.mastery));
    return weakest.take(kWeakestCardCount).toList();
  });
});

/// Mastery of one deck, for the Stats chart.
@immutable
class DeckMastery {
  const DeckMastery({
    required this.deckId,
    required this.title,
    required this.cardCount,
    required this.mastery,
  });

  final String deckId;
  final String title;
  final int cardCount;

  /// Average card mastery, 0.0 to 1.0 (0 for an empty deck).
  final double mastery;

  @override
  bool operator ==(Object other) =>
      other is DeckMastery &&
      other.deckId == deckId &&
      other.title == title &&
      other.cardCount == cardCount &&
      other.mastery == mastery;

  @override
  int get hashCode => Object.hash(deckId, title, cardCount, mastery);

  @override
  String toString() =>
      'DeckMastery($title, cards: $cardCount, mastery: $mastery)';
}

/// Mastery of every deck, in deck order.
final masteryByDeckProvider = Provider<AsyncValue<List<DeckMastery>>>(
  (ref) => _combine(ref.watch(decksProvider), ref.watch(deckStatsProvider), (
    decks,
    stats,
  ) {
    return [
      for (final deck in decks)
        DeckMastery(
          deckId: deck.id,
          title: deck.title,
          cardCount: stats[deck.id]?.cardCount ?? 0,
          mastery: stats[deck.id]?.mastery ?? 0,
        ),
    ];
  }),
);

/// Average mastery over all cards, so a large deck weighs more than a small
/// one. 0 when there are no cards.
double averageMastery(List<DeckMastery> decks) {
  var cards = 0;
  var total = 0.0;
  for (final deck in decks) {
    cards += deck.cardCount;
    total += deck.mastery * deck.cardCount;
  }
  return cards == 0 ? 0 : total / cards;
}

/// [combine] of both values once both have data; otherwise the first error,
/// or loading.
AsyncValue<R> _combine<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A a, B b) combine,
) {
  if (a.hasError) return AsyncError(a.error!, a.stackTrace!);
  if (b.hasError) return AsyncError(b.error!, b.stackTrace!);
  final av = a.valueOrNull;
  final bv = b.valueOrNull;
  if (av == null || bv == null) return const AsyncLoading();
  return AsyncData(combine(av, bv));
}
