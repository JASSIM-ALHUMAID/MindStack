import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/deck_import.dart';
import '../../application/inbox.dart';
import '../../application/library.dart';
import '../../application/services.dart';
import '../../domain/mindstack_file.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/draft_card.dart';
import '../../theme/app_theme.dart';
import '../save_feedback.dart';
import '../widgets/async_value_view.dart';
import '../widgets/common.dart';
import '../widgets/edit_draft_sheet.dart';

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

  /// Swiped drafts, hidden at once: a dismissed tile must leave the tree
  /// before the database stream catches up.
  final _hidden = <String>{};

  @override
  void didUpdateWidget(_InboxContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Once a deletion is stored the id is gone; forget it so Undo shows it.
    _hidden.retainWhere((id) => widget.drafts.any((d) => d.id == id));
  }

  Future<void> _deleteDraft(DraftCard draft) async {
    setState(() => _hidden.add(draft.id));
    final commands = ref.read(inboxCommandsProvider);
    // Captured now: Undo is tapped after this screen may have rebuilt.
    final messenger = ScaffoldMessenger.of(context);
    final logger = ref.read(loggerProvider);
    final ok = await runSaveWith(
      messenger,
      logger,
      () => commands.deleteDraft(draft.id),
    );
    if (!ok) {
      if (mounted) setState(() => _hidden.remove(draft.id));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Draft deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(
            runSaveWith(messenger, logger, () => commands.restoreDraft(draft)),
          ),
        ),
      ),
    );
  }

  void _notImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('On-device import arrives in Phase 4')),
    );
  }

  Future<void> _import(
    Future<MindstackFile?> Function(DeckImportNotifier) run,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final deck = await run(ref.read(deckImportProvider.notifier));
    if (deck == null) return;
    final n = deck.cards.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$n ${n == 1 ? 'draft' : 'drafts'} imported from ${deck.deckTitle}',
        ),
      ),
    );
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    final commands = ref.read(inboxCommandsProvider);
    await runSave(context, ref, commands.clear);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _chooseDeck() async {
    final decks = ref.read(decksProvider).valueOrNull ?? const <Deck>[];
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
    final drafts = [
      for (final d in widget.drafts)
        if (!_hidden.contains(d.id)) d,
    ];
    final selectedCount = drafts.where((d) => d.selected).length;
    final ocrProgress = ref.watch(ocrProgressProvider);
    final importState = ref.watch(deckImportProvider);
    final reading = importState is ImportReading;
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
                onPressed: reading
                    ? null
                    : () => _import((n) => n.pickAndImport()),
                icon: const Icon(LucideIcons.fileUp, size: 18),
                label: const Text('Import a shared deck (.mindstack)'),
              ),
              if (ocrProgress != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: ocrProgress),
              ],
              if (reading) ...[
                const SizedBox(height: 12),
                const Text('READING DECK FILE…', style: kMonoLabel),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (importState case ImportFailed(:final message)) ...[
                const SizedBox(height: 12),
                _ImportError(
                  message: message,
                  onRetry: () => _import((n) => n.retry()),
                  onChooseAnother: () => _import((n) => n.pickAndImport()),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Text('Draft cards', style: kSerifSection)),
            if (drafts.isNotEmpty)
              const Text('SWIPE LEFT TO DELETE', style: kMonoMicro),
          ],
        ),
        const SizedBox(height: 8),
        if (drafts.isEmpty && !reading)
          SoftCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                importState is ImportFailed
                    ? 'No drafts yet. Fix the import above.'
                    : 'No drafts yet. Import something above.',
              ),
            ),
          ),
        for (final draft in drafts) ...[
          Dismissible(
            key: ValueKey(draft.id),
            direction: DismissDirection.endToStart,
            background: const _DeleteBackground(),
            onDismissed: (_) => unawaited(_deleteDraft(draft)),
            child: _DraftTile(draft: draft),
          ),
          const SizedBox(height: 12),
        ],
        if (reading)
          for (var i = 0; i < 3; i++) ...[
            const _DraftSkeleton(),
            const SizedBox(height: 12),
          ],
        if (drafts.isNotEmpty)
          FilledButton(
            onPressed: selectedCount == 0 || _busy || !decksReady || reading
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

  const _DraftTile({required this.draft});

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
                      onPressed: () => showEditDraftSheet(context, draft),
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

/// Figma frame "Inbox (Error State)".
class _ImportError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onChooseAnother;

  const _ImportError({
    required this.message,
    required this.onRetry,
    required this.onChooseAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "COULDN'T READ THIS FILE",
          style: kMonoLabel.copyWith(color: AppColors.danger),
        ),
        const SizedBox(height: 8),
        const LinearProgressIndicator(value: 1, color: AppColors.danger),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("This file couldn't be read", style: kSerifSection),
              const SizedBox(height: 6),
              Text(message, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  child: const Text('Retry import'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onChooseAnother,
                  child: const Text('Choose another file'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Placeholder draft shown while a file is read (Figma "Inbox (Loading State)").
class _DraftSkeleton extends StatelessWidget {
  const _DraftSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return ExcludeSemantics(
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [bar(48, 16), const SizedBox(width: 8), bar(56, 16)]),
            const SizedBox(height: 40),
            bar(200, 10),
            const SizedBox(height: 8),
            bar(double.infinity, 10),
          ],
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.trash2, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Delete', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
