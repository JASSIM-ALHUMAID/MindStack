import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/cards.dart';
import '../../application/library.dart';
import '../../application/review.dart';
import '../../application/services.dart';
import '../../application/tab.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/flashcard.dart';
import '../../theme/app_theme.dart';
import '../save_feedback.dart';
import '../widgets/add_card_sheet.dart';
import '../widgets/async_value_view.dart';
import '../widgets/common.dart';

class DeckEditorScreen extends ConsumerWidget {
  final String deckId;

  const DeckEditorScreen({super.key, required this.deckId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(deckProvider(deckId));
    final loaded = deck.valueOrNull;
    if (loaded != null) return _DeckEditor(deck: loaded);
    // Loading, failed, or the deck does not exist (any more), for example
    // because it was deleted or merged while this screen was open.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Back to Library',
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AsyncValueView<Deck?>(
        value: deck,
        data: (_) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This deck no longer exists.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckEditor extends ConsumerStatefulWidget {
  final Deck deck;

  const _DeckEditor({required this.deck});

  @override
  ConsumerState<_DeckEditor> createState() => _DeckEditorState();
}

class _DeckEditorState extends ConsumerState<_DeckEditor> {
  /// True while a merge flow is running, so a second one cannot start.
  bool _merging = false;

  Future<void> _merge() async {
    if (_merging) return;
    setState(() => _merging = true);
    try {
      await _mergeDeck(context, ref, widget.deck);
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = widget.deck;
    final deckId = deck.id;
    final cardsValue = ref.watch(deckCardsProvider(deckId));
    final cards = cardsValue.valueOrNull ?? const <Flashcard>[];
    final now = ref.read(clockProvider).now();
    final reviewable = cards.where((c) => !c.dueAt.isAfter(now)).length;
    final newCount = cards.where((c) => c.isNew).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Back to Library',
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${cards.length} ${cards.length == 1 ? 'CARD' : 'CARDS'}',
              style: kMonoLabel,
            ),
            Text(deck.title, style: kSerifTitle.copyWith(fontSize: 22)),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => unawaited(showAddCardSheet(context, deckId)),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Card'),
          ),
          PopupMenuButton<_DeckAction>(
            tooltip: 'More deck actions',
            icon: const Icon(LucideIcons.ellipsisVertical),
            onSelected: (action) {
              switch (action) {
                case _DeckAction.merge:
                  // The menu callback is synchronous; the merge flow reports
                  // its own outcome through the sheet and snackbars.
                  unawaited(_merge());
                case _DeckAction.share:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deck sharing arrives in Phase 3'),
                    ),
                  );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _DeckAction.merge,
                enabled: !_merging,
                child: const ListTile(
                  leading: Icon(LucideIcons.merge),
                  title: Text('Merge into another deck'),
                ),
              ),
              const PopupMenuItem(
                value: _DeckAction.share,
                child: ListTile(
                  leading: Icon(LucideIcons.share),
                  title: Text('Share deck'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: AsyncValueView<List<Flashcard>>(
        value: cardsValue,
        data: (cards) => cards.isEmpty
            ? const Center(child: Text('No cards yet. Tap + Card to add one.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _CardTile(number: i + 1, card: cards[i]),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SoftCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    // min: the bottom bar slot allows the full screen height,
                    // so a max-size Column would push the card list off screen.
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DECK BALANCE', style: kMonoLabel),
                      Text('$reviewable reviewable · $newCount new'),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: cards.isEmpty
                      ? null
                      : () {
                          // Loads the queue in the background; the Review tab
                          // shows its own loading and error states.
                          unawaited(
                            ref.read(reviewProvider.notifier).startDeck(deckId),
                          );
                          ref.read(tabIndexProvider.notifier).set(2);
                          context.pop();
                        },
                  child: const Text('Study'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _DeckAction { merge, share }

/// Merge flow: pick the target deck in a bottom sheet, confirm in a dialog,
/// then move the cards, remove this deck and return to Library.
Future<void> _mergeDeck(BuildContext context, WidgetRef ref, Deck deck) async {
  final others = [
    for (final d in ref.read(decksProvider).valueOrNull ?? const <Deck>[])
      if (d.id != deck.id) d,
  ];
  final target = await showModalBottomSheet<Deck>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Merge into', style: kSerifSection),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'All cards from "${deck.title}" move to the deck you pick.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          for (final d in others)
            ListTile(
              title: Text(d.title),
              onTap: () => Navigator.pop(sheetContext, d),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) return;

  final count = ref.read(deckCardsProvider(deck.id)).valueOrNull?.length ?? 0;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Merge decks?'),
      content: Text(
        'Move $count cards from "${deck.title}" into "${target.title}". '
        '"${deck.title}" will be removed. Review history is kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Merge'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final commands = ref.read(libraryCommandsProvider);
  // The merge removes this deck, which replaces the editor with its
  // "no longer exists" state and unmounts [context]; leave through the router.
  final router = GoRouter.of(context);
  final saved = await runSave(
    context,
    ref,
    () => commands.mergeDecks(fromId: deck.id, toId: target.id),
    success: 'Merged "${deck.title}" into "${target.title}"',
  );
  if (saved) router.pop();
}

class _CardTile extends ConsumerStatefulWidget {
  final int number;
  final Flashcard card;

  const _CardTile({required this.number, required this.card});

  @override
  ConsumerState<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends ConsumerState<_CardTile> {
  bool _deleting = false;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    final commands = ref.read(cardCommandsProvider);
    final deleted = await runSave(
      context,
      ref,
      () => commands.deleteCard(widget.card.id),
      success: 'Card deleted',
    );
    // On success the tile leaves the list; on failure let the user retry.
    if (!deleted && mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final number = widget.number;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${number.toString().padLeft(2, '0')}', style: kMonoLabel),
              const Spacer(),
              PillLabel(card.isNew ? 'NEW' : '${card.intervalDays}D INTERVAL'),
            ],
          ),
          const SizedBox(height: 6),
          Text(card.question, style: kSerifTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text(card.answer, style: const TextStyle(color: AppColors.ink)),
          const Divider(height: 20),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'MASTERY: ${(card.mastery * 100).round()}%',
                style: kMonoLabel,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Card editing arrives in Phase 3'),
                  ),
                ),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: _deleting ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
