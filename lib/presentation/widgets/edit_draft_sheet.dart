import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/inbox.dart';
import '../../domain/models/draft_card.dart';
import '../save_feedback.dart';
import 'add_card_sheet.dart';
import 'sheet_scaffold.dart';

Future<void> showEditDraftSheet(BuildContext context, DraftCard draft) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SheetScaffold(child: _EditDraftSheet(draft: draft)),
  );
}

class _EditDraftSheet extends ConsumerWidget {
  final DraftCard draft;

  const _EditDraftSheet({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CardForm(
      title: 'Edit draft',
      pill: 'Draft',
      submitLabel: 'Save changes',
      initialQuestion: draft.question,
      initialAnswer: draft.answer,
      onSave: (question, answer) {
        final commands = ref.read(inboxCommandsProvider);
        return runSave(
          context,
          ref,
          () => commands.updateDraft(
            id: draft.id,
            question: question,
            answer: answer,
          ),
        );
      },
    );
  }
}
