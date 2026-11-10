import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/cards.dart';
import '../../theme/app_theme.dart';
import '../save_feedback.dart';
import 'common.dart';
import 'sheet_scaffold.dart';

Future<void> showAddCardSheet(BuildContext context, String deckId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SheetScaffold(child: _AddCardSheet(deckId: deckId)),
  );
}

class _AddCardSheet extends ConsumerWidget {
  final String deckId;

  const _AddCardSheet({required this.deckId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The number is cosmetic, so it is left blank rather than blocking the
    // form while the count loads or if it fails.
    final count = ref.watch(deckCardsProvider(deckId)).valueOrNull?.length;
    return CardForm(
      title: 'Add card',
      meta: count == null ? null : '#${count + 1} IN DECK',
      pill: 'Drafting',
      submitLabel: 'Save card',
      onSave: (question, answer) {
        final commands = ref.read(cardCommandsProvider);
        return runSave(
          context,
          ref,
          () => commands.addCard(
            deckId: deckId,
            question: question,
            answer: answer,
          ),
        );
      },
    );
  }
}

/// The question and answer form shared by the Add Card and Edit Card sheets.
/// Validates both fields, calls [onSave] and closes the sheet when it
/// returns `true`; on `false` the form stays open so the user can retry.
class CardForm extends StatefulWidget {
  /// Sheet heading, for example "Add card".
  final String title;

  /// Small mono label next to [title]; hidden when null.
  final String? meta;

  /// Pill at the end of the heading row.
  final String pill;

  /// Label of the primary button.
  final String submitLabel;

  /// Starting text of the question and answer fields.
  final String initialQuestion;
  final String initialAnswer;

  /// Writes the trimmed-by-the-command text and reports the outcome; returns
  /// whether it was saved.
  final Future<bool> Function(String question, String answer) onSave;

  const CardForm({
    super.key,
    required this.title,
    required this.pill,
    required this.submitLabel,
    required this.onSave,
    this.meta,
    this.initialQuestion = '',
    this.initialAnswer = '',
  });

  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  final _formKey = GlobalKey<FormState>();
  late final _questionController = TextEditingController(
    text: widget.initialQuestion,
  );
  late final _answerController = TextEditingController(
    text: widget.initialAnswer,
  );
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
    final navigator = Navigator.of(context);
    final saved = await widget.onSave(
      _questionController.text,
      _answerController.text,
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
    final meta = widget.meta;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.title, style: kSerifTitle),
                const SizedBox(width: 8),
                if (meta != null) Text(meta, style: kMonoLabel),
                const Spacer(),
                PillLabel(widget.pill),
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
            const SizedBox(height: 12),
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
                label: Text(widget.submitLabel),
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
