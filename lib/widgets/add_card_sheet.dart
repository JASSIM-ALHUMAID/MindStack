import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
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

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    ref.read(cardsProvider.notifier).add(
          Flashcard(
            id: 'k${now.microsecondsSinceEpoch}',
            deckId: widget.deckId,
            question: _questionController.text.trim(),
            answer: _answerController.text.trim(),
            dueAt: now,
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cardNumber = ref.watch(deckCardsProvider(widget.deckId)).length + 1;
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
                Text('#$cardNumber IN DECK', style: kMonoLabel),
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
                  Icon(LucideIcons.bookOpen, size: 18, color: AppColors.primary),
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
                onPressed: _save,
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
