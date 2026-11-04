import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/inbox.dart';
import '../../application/library.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/draft_card.dart';
import '../../theme/app_theme.dart';
import '../save_feedback.dart';
import '../widgets/async_value_view.dart';
import '../widgets/common.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<DraftCard>>(
      value: ref.watch(draftsProvider),
      data: (drafts) => _InboxContent(drafts: drafts),
    );
  }
}

class _InboxContent extends ConsumerStatefulWidget {
  final List<DraftCard> drafts;

  const _InboxContent({required this.drafts});

  @override
  ConsumerState<_InboxContent> createState() => _InboxContentState();
}

class _InboxContentState extends ConsumerState<_InboxContent> {
  /// True while CLEAR or "Save selected" is writing, so neither can be
  /// started twice.
  bool _busy = false;

  void _notImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('On-device import arrives in Phase 3')),
    );
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    final commands = ref.read(inboxCommandsProvider);
    await runSave(context, ref, commands.clear);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _chooseDeck() async {
    final decks = ref.read(decksProvider).value ?? const <Deck>[];
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
    if (deckId == null || !mounted) return;
    setState(() => _busy = true);
    final commands = ref.read(inboxCommandsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final deckTitle = decks.firstWhere((d) => d.id == deckId).title;
    int? count;
    final saved = await runSave(context, ref, () async {
      count = await commands.saveSelectedTo(deckId);
    });
    if (saved) {
      messenger.showSnackBar(
        SnackBar(content: Text('$count cards saved to $deckTitle')),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final drafts = widget.drafts;
    final selectedCount = drafts.where((d) => d.selected).length;
    final ocrProgress = ref.watch(ocrProgressProvider);
    // Watched so the decks are loaded by the time the deck chooser opens; the
    // save button stays disabled until they are.
    final decksReady = ref.watch(decksProvider).hasValue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ScreenHeader(
          eyebrow: 'OCR QUEUE · ${drafts.length} PENDING',
          title: 'Inbox',
          trailing: TextButton(
            onPressed: drafts.isEmpty || _busy ? null : _clear,
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
                  const SnackBar(
                    content: Text('Importing shared decks arrives in Phase 3'),
                  ),
                ),
                icon: const Icon(LucideIcons.fileUp, size: 18),
                label: const Text('Import a shared deck (.mindstack)'),
              ),
              if (ocrProgress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: ocrProgress),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Draft cards', style: kSerifSection),
        const SizedBox(height: 8),
        if (drafts.isEmpty)
          const SoftCard(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No drafts yet. Import something above.'),
            ),
          ),
        for (final draft in drafts) ...[
          _DraftTile(key: ValueKey(draft.id), draft: draft),
          const SizedBox(height: 12),
        ],
        if (drafts.isNotEmpty)
          FilledButton(
            onPressed: selectedCount == 0 || _busy || !decksReady
                ? null
                : _chooseDeck,
            child: Text('Save selected ($selectedCount) to a deck'),
          ),
      ],
    );
  }
}

class _DraftTile extends ConsumerStatefulWidget {
  final DraftCard draft;

  const _DraftTile({super.key, required this.draft});

  @override
  ConsumerState<_DraftTile> createState() => _DraftTileState();
}

class _DraftTileState extends ConsumerState<_DraftTile> {
  bool _toggling = false;

  Future<void> _toggle() async {
    setState(() => _toggling = true);
    final commands = ref.read(inboxCommandsProvider);
    await runSave(context, ref, () => commands.toggle(widget.draft.id));
    if (mounted) setState(() => _toggling = false);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Round checkmark from Figma. IconButton keeps a 48 dp tap target.
          IconButton(
            tooltip: draft.selected
                ? 'Leave out this draft'
                : 'Keep this draft',
            onPressed: _toggling ? null : _toggle,
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
                      child: Text(
                        draft.sourceRef.toUpperCase(),
                        style: kMonoMicro,
                      ),
                    ),
                    TextButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Editing drafts arrives in Phase 3',
                              ),
                            ),
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
