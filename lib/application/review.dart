import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/failures.dart';
import '../domain/models/flashcard.dart';
import 'cards.dart';
import 'core_providers.dart';

/// An immutable snapshot of a review session: a queue of card ids and the
/// position within it. The cards themselves are resolved from live data.
@immutable
class ReviewState {
  /// Creates a session over [cardIds], at [index], optionally [saving].
  const ReviewState({
    required this.cardIds,
    this.index = 0,
    this.saving = false,
  });

  /// Ids of the cards in this session, in review order.
  final List<String> cardIds;

  /// Position of the current card in [cardIds].
  final int index;

  /// Whether a rating is being written.
  final bool saving;

  /// Whether every card in the queue has been rated.
  bool get finished => index >= cardIds.length;

  /// Id of the card to show, or null when [finished].
  String? get currentId => finished ? null : cardIds[index];

  /// A copy with the given fields replaced.
  ReviewState copyWith({List<String>? cardIds, int? index, bool? saving}) {
    return ReviewState(
      cardIds: cardIds ?? this.cardIds,
      index: index ?? this.index,
      saving: saving ?? this.saving,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewState &&
      other.index == index &&
      other.saving == saving &&
      listEquals(other.cardIds, cardIds);

  @override
  int get hashCode => Object.hash(index, saving, Object.hashAll(cardIds));
}

/// The review session. The queue is a point-in-time snapshot of card ids;
/// each card is read live through [currentReviewCardProvider].
class ReviewNotifier extends AsyncNotifier<ReviewState> {
  /// Bumped whenever the queue is replaced or restarted, so an in-flight
  /// [rate] can tell its session is gone.
  int _session = 0;

  @override
  Future<ReviewState> build() async {
    _session++;
    final due = await ref
        .read(cardRepositoryProvider)
        .due(now: ref.read(clockProvider).now());
    return ReviewState(cardIds: [for (final c in due) c.id]);
  }

  /// Rates the current card and moves to the next one.
  ///
  /// Does nothing while a rating is being saved or when the session is
  /// finished. On failure the index stays put, the failure is rethrown for
  /// the caller to show, and the session itself stays usable.
  ///
  /// Throws [NotFound] if the card no longer exists and [StorageFailure] if
  /// the write fails.
  Future<void> rate(Rating rating) async {
    final current = state.value;
    if (state.isLoading || current == null || current.saving) return;
    if (current.finished) return;
    final session = _session;
    state = AsyncData(current.copyWith(saving: true));
    try {
      await ref.read(cardCommandsProvider).rateCard(current.currentId!, rating);
    } catch (_) {
      // Any failure, not only AppFailure, must release the saving flag.
      if (session == _session) {
        state = AsyncData(current.copyWith(saving: false));
      }
      rethrow;
    }
    // A restart or a new queue replaced this session while the write ran;
    // the rating is stored but must not touch the new queue.
    if (session != _session) return;
    state = AsyncData(current.copyWith(index: current.index + 1));
  }

  /// "Review again": returns to the first card of the same queue.
  void restart() {
    final current = state.value;
    if (current == null) return;
    _session++;
    state = AsyncData(current.copyWith(index: 0, saving: false));
  }

  /// Studies every card of [deckId] (from the Deck Editor).
  Future<void> startDeck(String deckId) async {
    await _start(
      () => ref.read(cardRepositoryProvider).watchByDeck(deckId).first,
      (cards) => cards,
    );
  }

  /// Drills the [count] cards with the lowest mastery (from Stats or Quiz
  /// results).
  Future<void> startWeak({int count = 3}) async {
    await _start(
      () => ref.read(cardRepositoryProvider).watchAll().first,
      (cards) => ([
        ...cards,
      ]..sort((a, b) => a.mastery.compareTo(b.mastery))).take(count).toList(),
    );
  }

  Future<void> _start(
    Future<List<Flashcard>> Function() load,
    List<Flashcard> Function(List<Flashcard>) select,
  ) async {
    _session++;
    state = const AsyncLoading<ReviewState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final cards = select(await load());
      return ReviewState(cardIds: [for (final c in cards) c.id]);
    });
  }
}

/// The review session.
final reviewProvider = AsyncNotifierProvider<ReviewNotifier, ReviewState>(
  ReviewNotifier.new,
);

/// The card being reviewed, read live. Data is null when the session is
/// finished or the card was deleted since the queue was built.
final currentReviewCardProvider = Provider<AsyncValue<Flashcard?>>((ref) {
  final session = ref.watch(reviewProvider);
  final cards = ref.watch(allCardsProvider);
  if (session.hasError) {
    return AsyncError(session.error!, session.stackTrace!);
  }
  if (cards.hasError) return AsyncError(cards.error!, cards.stackTrace!);
  final state = session.value;
  final all = cards.value;
  if (state == null || all == null) return const AsyncLoading();
  final id = state.currentId;
  if (id == null) return const AsyncData(null);
  for (final card in all) {
    if (card.id == id) return AsyncData(card);
  }
  return const AsyncData(null);
});
