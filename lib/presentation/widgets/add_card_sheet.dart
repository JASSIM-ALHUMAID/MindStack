import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/cards.dart';
import '../../theme/app_theme.dart';
import '../save_feedback.dart';
import 'common.dart';

Future<void> showAddCardSheet(BuildContext context, String deckId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (_) => _AddCardSheet(deckId: deckId),
  );
}

class _AddCardSheet extends ConsumerStatefulWidget {
  final String deckId;

  const _AddCardSheet({required this.deckId});

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final commands = ref.read(cardCommandsProvider);
    final navigator = Navigator.of(context);
    final saved = await runSave(
      context,
      ref,
      () => commands.addCard(
        deckId: widget.deckId,
        question: _questionController.text,
        answer: _answerController.text,
      ),
    );
    // The sheet may have been dismissed while saving; then there is nothing
    // left to close or re-enable.
    if (!mounted) return;
    if (saved) {
      navigator.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The number is cosmetic, so it is left blank rather than blocking the
    // form while the count loads or if it fails.
    final count = ref.watch(deckCardsProvider(widget.deckId)).value?.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Add card', style: kSerifTitle),
                const SizedBox(width: 8),
                if (count != null)
                  Text('#${count + 1} IN DECK', style: kMonoLabel),
                const Spacer(),
                const PillLabel('Drafting'),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _questionController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Question'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a question' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _answerController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Answer'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter an answer' : null,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.bookOpen,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Why: concrete definitions are easier to recall on a spaced schedule.',
                      style: kBodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                iconAlignment: IconAlignment.end,
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                label: const Text('Save card'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
