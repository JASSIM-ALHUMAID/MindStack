import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/draft_card.dart';
import '../providers/inbox_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  void _notImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('On-device import arrives in Phase 3')),
    );
  }

  Future<void> _chooseDeck(BuildContext context, WidgetRef ref) async {
    final decks = ref.read(decksProvider);
    final deckId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Choose deck', style: kSerifSection),
            ),
            for (final deck in decks)
              ListTile(
                title: Text(deck.title),
                onTap: () => Navigator.pop(sheetContext, deck.id),
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
    if (deckId == null || !context.mounted) return;
    final count = ref.read(inboxProvider.notifier).saveSelectedTo(deckId);
    final deckTitle = decks.firstWhere((d) => d.id == deckId).title;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count cards saved to $deckTitle')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ScreenHeader(
          eyebrow: 'OCR QUEUE · ${inbox.drafts.length} PENDING',
          title: 'Inbox',
          trailing: TextButton(
            onPressed: inbox.drafts.isEmpty
                ? null
                : () => ref.read(inboxProvider.notifier).clear(),
            child: const Text('CLEAR', style: kMonoLabel),
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Import material', style: kSerifSection),
              const SizedBox(height: 8),
              const Text(
                'Screenshots, camera photos, or lecture PDFs. Everything is read on-device; nothing leaves the phone.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _notImplemented(context),
                      icon: const Icon(LucideIcons.camera),
                      label: const Text('Screenshots'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _notImplemented(context),
                      icon: const Icon(LucideIcons.fileText),
                      label: const Text('PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Importing shared decks arrives in Phase 3')),
                ),
                icon: const Icon(LucideIcons.fileUp, size: 18),
                label: const Text('Import a shared deck (.mindstack)'),
              ),
              if (inbox.ocrProgress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: inbox.ocrProgress),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Draft cards', style: kSerifSection),
        const SizedBox(height: 8),
        if (inbox.drafts.isEmpty)
          const SoftCard(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No drafts yet. Import something above.')),
          ),
        for (final draft in inbox.drafts) ...[
          _DraftTile(draft: draft),
          const SizedBox(height: 12),
        ],
        if (inbox.drafts.isNotEmpty)
          FilledButton(
            onPressed: inbox.selectedCount == 0 ? null : () => _chooseDeck(context, ref),
            child: Text('Save selected (${inbox.selectedCount}) to a deck'),
          ),
      ],
    );
  }
}

class _DraftTile extends ConsumerWidget {
  final DraftCard draft;

  const _DraftTile({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Round checkmark from Figma. IconButton keeps a 48 dp tap target.
          IconButton(
            tooltip: draft.selected ? 'Leave out this draft' : 'Keep this draft',
            onPressed: () => ref.read(inboxProvider.notifier).toggle(draft.id),
            icon: Icon(
              draft.selected ? LucideIcons.circleCheck : LucideIcons.circle,
              color: draft.selected ? AppColors.primary : AppColors.muted,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PillLabel(draft.source.name),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(draft.sourceRef.toUpperCase(), style: kMonoMicro),
                    ),
                    TextButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Editing drafts arrives in Phase 3')),
                      ),
                      child: const Text('EDIT', style: kMonoLabel),
                    ),
                  ],
                ),
                Text(draft.question, style: kSerifTitle.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(draft.answer, style: kBodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
