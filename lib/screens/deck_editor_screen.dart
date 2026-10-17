import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../providers/review_provider.dart';
import '../providers/tab_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/add_card_sheet.dart';
import '../widgets/common.dart';

class DeckEditorScreen extends ConsumerWidget {
  final String deckId;

  const DeckEditorScreen({super.key, required this.deckId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(decksProvider).where((d) => d.id == deckId).firstOrNull;
    // The deck can disappear while this screen closes after a merge.
    if (deck == null) return const Scaffold();
    final cards = ref.watch(deckCardsProvider(deckId));
    final reviewable = cards.where((c) => !c.dueAt.isAfter(DateTime.now())).length;
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
            Text('${cards.length} ${cards.length == 1 ? 'CARD' : 'CARDS'}', style: kMonoLabel),
            Text(deck.title, style: kSerifTitle.copyWith(fontSize: 22)),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => showAddCardSheet(context, deckId),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Card'),
          ),
          PopupMenuButton<_DeckAction>(
            tooltip: 'More deck actions',
            icon: const Icon(LucideIcons.ellipsisVertical),
            onSelected: (action) {
              switch (action) {
                case _DeckAction.merge:
                  _mergeDeck(context, ref, deck);
                  break;
                case _DeckAction.share:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deck sharing arrives in Phase 3')),
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _DeckAction.merge,
                child: ListTile(
                  leading: Icon(LucideIcons.merge),
                  title: Text('Merge into another deck'),
                ),
              ),
              PopupMenuItem(
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
      body: cards.isEmpty
          ? const Center(child: Text('No cards yet. Tap + Card to add one.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _CardTile(number: i + 1, card: cards[i]),
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
                          ref.read(reviewProvider.notifier).startDeck(deckId);
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
  final others = ref.read(decksProvider).where((d) => d.id != deck.id).toList();
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

  final count = ref.read(deckCardsProvider(deck.id)).length;
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

  final messenger = ScaffoldMessenger.of(context);
  context.pop();
  ref.read(cardsProvider.notifier).moveToDeck(deck.id, target.id);
  ref.read(decksProvider.notifier).remove(deck.id);
  messenger.showSnackBar(
    SnackBar(content: Text('Merged "${deck.title}" into "${target.title}"')),
  );
}

class _CardTile extends ConsumerWidget {
  final int number;
  final Flashcard card;

  const _CardTile({required this.number, required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Text('MASTERY: ${(card.mastery * 100).round()}%', style: kMonoLabel),
              const Spacer(),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card editing arrives in Phase 3')),
                ),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(cardsProvider.notifier).remove(card.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card deleted')),
                  );
                },
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
