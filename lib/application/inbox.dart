import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/failures.dart';
import '../domain/models/draft_card.dart';
import '../domain/models/flashcard.dart';
import 'core_providers.dart';

/// Live list of OCR drafts awaiting a decision.
final draftsProvider = StreamProvider<List<DraftCard>>(
  (ref) => ref.watch(draftRepositoryProvider).watchAll(),
);

/// Writes to the draft inbox.
final inboxCommandsProvider = Provider<InboxCommands>(InboxCommands.new);

/// Operations on the OCR draft inbox.
final class InboxCommands {
  /// Creates the commands reading its dependencies from [_ref] at call time.
  const InboxCommands(this._ref);

  final Ref _ref;

  /// Flips whether draft [id] is ticked.
  ///
  /// Throws [NotFound] if the draft does not exist and [StorageFailure] if
  /// the write fails.
  Future<void> toggle(String id) =>
      _ref.read(draftRepositoryProvider).toggleSelected(id);

  /// Deletes every draft.
  ///
  /// Throws [StorageFailure] if the write fails.
  Future<void> clear() => _ref.read(draftRepositoryProvider).clear();

  /// Turns the ticked drafts into cards in [deckId], due now, and deletes
  /// those drafts, in one transaction. Returns the number saved.
  ///
  /// Throws [InvalidInput] when no draft is ticked, [NotFound] if the deck
  /// does not exist, and [StorageFailure] if a write fails. Nothing is
  /// changed on failure.
  Future<int> saveSelectedTo(String deckId) {
    return _ref.read(transactionRunnerProvider).run(() async {
      final drafts = await _ref.read(draftRepositoryProvider).selected();
      if (drafts.isEmpty) {
        throw const InvalidInput(
          field: 'drafts',
          reason: 'Tick at least one draft to save.',
        );
      }
      final ids = _ref.read(idGeneratorProvider);
      final now = _ref.read(clockProvider).now();
      await _ref.read(cardRepositoryProvider).insertAll([
        for (final d in drafts)
          Flashcard(
            id: ids.newId(),
            deckId: deckId,
            question: d.question,
            answer: d.answer,
            source: d.source,
            sourceRef: d.sourceRef,
            dueAt: now,
          ),
      ]);
      await _ref.read(draftRepositoryProvider).delete([
        for (final d in drafts) d.id,
      ]);
      return drafts.length;
    });
  }
}
