import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flashcard.dart';
import 'library_provider.dart';

class ReviewState {
  final List<Flashcard> queue;
  final int index;

  const ReviewState({required this.queue, required this.index});

  bool get finished => index >= queue.length;
  Flashcard? get current => finished ? null : queue[index];
}

class ReviewNotifier extends Notifier<ReviewState> {
  @override
  ReviewState build() => ReviewState(queue: _dueCards(), index: 0);

  List<Flashcard> _dueCards() {
    final now = DateTime.now();
    return ref.read(cardsProvider).where((c) => !c.dueAt.isAfter(now)).toList();
  }

  /// Rates the current card and moves to the next one.
  void rate(Rating rating) {
    final card = state.current;
    if (card == null) return;
    ref.read(cardsProvider.notifier).rate(card.id, rating);
    state = ReviewState(queue: state.queue, index: state.index + 1);
  }

  /// "Review again" on the session-complete screen.
  void restart() {
    state = ReviewState(queue: state.queue, index: 0);
  }

  /// Study one deck (from the Deck Editor).
  void startDeck(String deckId) {
    final cards = ref.read(cardsProvider).where((c) => c.deckId == deckId).toList();
    state = ReviewState(queue: cards, index: 0);
  }

  /// Drill the weakest cards (from Stats or Quiz results).
  void startWeak({int count = 3}) {
    final cards = [...ref.read(cardsProvider)]
      ..sort((a, b) => a.mastery.compareTo(b.mastery));
    state = ReviewState(queue: cards.take(count).toList(), index: 0);
  }
}

final reviewProvider =
    NotifierProvider<ReviewNotifier, ReviewState>(ReviewNotifier.new);
