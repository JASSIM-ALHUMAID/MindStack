import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/failures.dart';
import '../domain/models/deck_stats.dart';
import '../domain/models/flashcard.dart';
import '../domain/scheduler.dart';
import 'core_providers.dart';
import 'validation.dart';

/// Live list of every card.
final allCardsProvider = StreamProvider<List<Flashcard>>(
  (ref) => ref.watch(cardRepositoryProvider).watchAll(),
);

/// Live list of the cards in one deck.
final deckCardsProvider = StreamProvider.autoDispose
    .family<List<Flashcard>, String>(
      (ref, deckId) => ref.watch(cardRepositoryProvider).watchByDeck(deckId),
    );

/// Live per-deck card counts and mastery, keyed by deck id.
final deckStatsProvider = StreamProvider<Map<String, DeckStats>>(
  (ref) => ref.watch(cardRepositoryProvider).watchDeckStats(),
);

/// Writes to flashcards.
final cardCommandsProvider = Provider<CardCommands>(CardCommands.new);

/// Validated writes to flashcards.
final class CardCommands {
  /// Creates the commands reading its dependencies from [_ref] at call time.
  const CardCommands(this._ref);

  final Ref _ref;

  /// Adds a new card to [deckId], due now, and returns its id. [question],
  /// [answer] and [sourceRef] are trimmed; a blank [sourceRef] is dropped.
  ///
  /// Throws [InvalidInput] for a blank question or answer, [NotFound] if the
  /// deck does not exist, and [StorageFailure] if the write fails.
  Future<String> addCard({
    required String deckId,
    required String question,
    required String answer,
    CardSource source = CardSource.manual,
    String? sourceRef,
  }) async {
    final q = requireText(
      question,
      field: 'question',
      reason: 'Enter a question.',
    );
    final a = requireText(answer, field: 'answer', reason: 'Enter an answer.');
    final ref = sourceRef?.trim();
    final id = _ref.read(idGeneratorProvider).newId();
    await _ref
        .read(cardRepositoryProvider)
        .insert(
          Flashcard(
            id: id,
            deckId: deckId,
            question: q,
            answer: a,
            source: source,
            sourceRef: (ref == null || ref.isEmpty) ? null : ref,
            dueAt: _ref.read(clockProvider).now(),
          ),
        );
    return id;
  }

  /// Deletes card [id].
  ///
  /// Throws [NotFound] if the card does not exist and [StorageFailure] if the
  /// write fails.
  Future<void> deleteCard(String id) =>
      _ref.read(cardRepositoryProvider).delete(id);

  /// Reschedules card [id] for [rating] at the current time and returns the
  /// stored card. The read and the write share one transaction.
  ///
  /// Throws [NotFound] if the card does not exist and [StorageFailure] if a
  /// storage call fails.
  Future<Flashcard> rateCard(String id, Rating rating) {
    return _ref.read(transactionRunnerProvider).run(() async {
      final cards = _ref.read(cardRepositoryProvider);
      final rated = Sm2Scheduler.apply(
        await cards.byId(id),
        rating,
        now: _ref.read(clockProvider).now(),
      );
      await cards.update(rated);
      return rated;
    });
  }
}
