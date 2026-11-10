import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cards.dart';
import '../../domain/models/flashcard.dart';
import '../save_feedback.dart';
import 'add_card_sheet.dart';
import 'sheet_scaffold.dart';

/// Opens the Edit Card sheet for [card]. Only the question and answer change;
/// the card keeps its schedule and mastery.
Future<void> showEditCardSheet(BuildContext context, Flashcard card) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SheetScaffold(child: _EditCardSheet(card: card)),
  );
}

class _EditCardSheet extends ConsumerWidget {
  final Flashcard card;

  const _EditCardSheet({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CardForm(
      title: 'Edit card',
      pill: 'Editing',
      submitLabel: 'Save changes',
      initialQuestion: card.question,
      initialAnswer: card.answer,
      onSave: (question, answer) {
        final commands = ref.read(cardCommandsProvider);
        return runSave(
          context,
          ref,
          () => commands.updateCard(
            id: card.id,
            question: question,
            answer: answer,
          ),
        );
      },
    );
  }
}
