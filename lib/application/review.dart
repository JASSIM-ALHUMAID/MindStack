import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/failures.dart';
import '../domain/models/flashcard.dart';
import '../domain/models/review_result.dart';
import 'cards.dart';
import 'core_providers.dart';
import 'services.dart';

/// An immutable snapshot of a review session: a queue of card ids and the
/// position within it. The cards themselves are resolved from live data.
@immutable
class ReviewState {
  /// Creates a session over [cardIds], at [index], optionally [saving].
  const ReviewState({
    required this.cardIds,
    this.index = 0,
    this.saving = false,
    this.results = const [],
    this.sessionId = 0,
  });

  /// Ids of the cards in this session, in review order.
  final List<String> cardIds;

  /// Position of the current card in [cardIds].
  final int index;

  /// Whether a rating is being written.
  final bool saving;

  /// Successful, committed ratings from this session only. Skipped cards
  /// and failed saves do not add a result.
  final List<ReviewResult> results;

  /// Distinguishes a new session from a previous one showing the same card.
  final int sessionId;

  int get reviewedCount => results.length;

  /// Sum of the per-card times stored in this session's review logs.
  int get elapsedMs =>
      results.fold(0, (total, result) => total + result.log.elapsedMs);

  double get secondsPerCard =>
      reviewedCount == 0 ? 0 : elapsedMs / 1000 / reviewedCount;

  /// Earliest due date assigned by this session's successful ratings.
  DateTime? get nextDue {
    if (results.isEmpty) return null;
    return results
        .map((result) => result.card.dueAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Whether every card in the queue has been rated.
  bool get finished => index >= cardIds.length;

  /// Id of the card to show, or null when [finished].
  String? get currentId => finished ? null : cardIds[index];

  /// A copy with the given fields replaced.
  ReviewState copyWith({
    List<String>? cardIds,
    int? index,
    bool? saving,
    List<ReviewResult>? results,
    int? sessionId,
  }) {
    return ReviewState(
      cardIds: cardIds ?? this.cardIds,
      index: index ?? this.index,
      saving: saving ?? this.saving,
      results: results ?? this.results,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewState &&
      other.index == index &&
      other.saving == saving &&
      other.sessionId == sessionId &&
      listEquals(other.results, results) &&
      listEquals(other.cardIds, cardIds);

  @override
  int get hashCode => Object.hash(
    index,
    saving,
    sessionId,
    Object.hashAll(cardIds),
    Object.hashAll(results),
  );
}

/// The review session. The queue is a point-in-time snapshot of card ids;
/// each card is read live through [currentReviewCardProvider].
class ReviewNotifier extends AsyncNotifier<ReviewState> {
  /// Bumped whenever the queue is replaced or restarted, so an in-flight
  /// [rate] can tell its session is gone.
  int _session = 0;

  DateTime? _cardStartedAt;
  bool _building = false;

  @override
  Future<ReviewState> build() async {
    _building = true;
    final session = ++_session;
    try {
      final due = await ref
          .read(cardRepositoryProvider)
          .due(now: ref.read(clockProvider).now());
      _cardStartedAt = ref.read(clockProvider).now();
      return ReviewState(
        cardIds: [for (final c in due) c.id],
        sessionId: session,
      );
    } finally {
      _building = false;
    }
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
    final current = state.valueOrNull;
    if (state.isLoading || current == null || current.saving) return;
    if (current.finished) return;
    final session = _session;
    final now = ref.read(clockProvider).now();
    final elapsedMs = now.difference(_cardStartedAt ?? now).inMilliseconds;
    state = AsyncData(current.copyWith(saving: true));
    late final ReviewResult result;
    try {
      result = await ref
          .read(cardCommandsProvider)
          .recordRating(
            current.currentId!,
            rating,
            elapsedMs: elapsedMs < 0 ? 0 : elapsedMs,
          );
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
    _cardStartedAt = ref.read(clockProvider).now();
    state = AsyncData(
      current.copyWith(
        index: current.index + 1,
        results: List<ReviewResult>.unmodifiable([...current.results, result]),
      ),
    );
  }

  /// Moves past the current card without rating it, for a card that was
  /// deleted since the queue was built. Does nothing while loading, saving or
  /// finished.
  void skip() {
    final current = state.valueOrNull;
    if (state.isLoading || current == null || current.saving) return;
    if (current.finished) return;
    _cardStartedAt = ref.read(clockProvider).now();
    state = AsyncData(current.copyWith(index: current.index + 1));
  }

  /// "Review again": returns to the first card of the same queue.
  void restart() {
    final current = state.valueOrNull;
    if (current == null) return;
    final session = ++_session;
    _cardStartedAt = ref.read(clockProvider).now();
    state = AsyncData(
      current.copyWith(
        index: 0,
        saving: false,
        results: const [],
        sessionId: session,
      ),
    );
  }

  /// Loads a fresh session. By default only cards due now are included,
  /// optionally limited to [deckId]. Explicit [cardIds] select practice cards
  /// regardless of due date, preserving order and removing duplicates.
  /// Missing ids are skipped; an explicit empty list creates an empty session.
  Future<void> start({String? deckId, List<String>? cardIds}) async {
    // Copy the caller's list before the asynchronous load begins.
    final selectedIds = cardIds == null ? null : [...cardIds];
    await _start(() async {
      final repository = ref.read(cardRepositoryProvider);
      if (selectedIds == null) {
        return repository.due(
          now: ref.read(clockProvider).now(),
          deckId: deckId,
        );
      }
      final cards = await repository.watchAll().first;
      final byId = {
        for (final card in cards)
          if (deckId == null || card.deckId == deckId) card.id: card,
      };
      return [for (final id in selectedIds.toSet()) ?byId[id]];
    }, (cards) => cards);
  }

  /// Studies cards currently due in [deckId] (from the Deck Editor).
  Future<void> startDeck(String deckId) => start(deckId: deckId);

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
    // The initial AsyncNotifier build owns its result. Let it finish before
    // replacing the queue, otherwise it could overwrite a targeted session.
    if (_building) {
      try {
        await future;
      } catch (_) {
        // A fresh start is also allowed to retry a failed initial load.
      }
    }
    final session = ++_session;
    state = const AsyncLoading<ReviewState>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() async {
      final cards = select(await load());
      return ReviewState(
        cardIds: [for (final c in cards) c.id],
        sessionId: session,
      );
    });
    // A newer start, restart or rebuild replaced this one while it loaded;
    // its queue (or failure) must not overwrite the newer session.
    if (session != _session) return;
    if (result.hasValue) _cardStartedAt = ref.read(clockProvider).now();
    state = result;
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
  final state = session.valueOrNull;
  final all = cards.valueOrNull;
  if (state == null || all == null) return const AsyncLoading();
  final id = state.currentId;
  if (id == null) return const AsyncData(null);
  for (final card in all) {
    if (card.id == id) return AsyncData(card);
  }
  return const AsyncData(null);
});
