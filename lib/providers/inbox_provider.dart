import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_data.dart';
import '../models/draft_card.dart';
import '../models/flashcard.dart';
import 'library_provider.dart';

class InboxState {
  final List<DraftCard> drafts;

  /// 0.0 to 1.0 while OCR is running, null when idle.
  final double? ocrProgress;

  const InboxState({required this.drafts, this.ocrProgress});

  int get selectedCount => drafts.where((d) => d.selected).length;
}

class InboxNotifier extends Notifier<InboxState> {
  @override
  InboxState build() => InboxState(drafts: List<DraftCard>.of(sampleDrafts));

  void toggle(String id) {
    state = InboxState(
      ocrProgress: state.ocrProgress,
      drafts: [
        for (final d in state.drafts) d.id == id ? d.copyWith(selected: !d.selected) : d,
      ],
    );
  }

  /// CLEAR in the Inbox header: removes every draft.
  void clear() => state = InboxState(drafts: const [], ocrProgress: state.ocrProgress);

  /// Saves the selected drafts as cards in [deckId] and removes them from
  /// the inbox. Returns how many cards were saved.
  int saveSelectedTo(String deckId) {
    final selected = state.drafts.where((d) => d.selected).toList();
    final now = DateTime.now();
    final cards = [
      for (final d in selected)
        Flashcard(
          id: 'k${now.microsecondsSinceEpoch}_${d.id}',
          deckId: deckId,
          question: d.question,
          answer: d.answer,
          source: d.source,
          sourceRef: d.sourceRef,
          dueAt: now,
        ),
    ];
    ref.read(cardsProvider.notifier).addAll(cards);
    state = InboxState(
      ocrProgress: state.ocrProgress,
      drafts: state.drafts.where((d) => !d.selected).toList(),
    );
    return cards.length;
  }
}

final inboxProvider =
    NotifierProvider<InboxNotifier, InboxState>(InboxNotifier.new);
