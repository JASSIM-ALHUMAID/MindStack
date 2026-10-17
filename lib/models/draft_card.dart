import 'flashcard.dart';

/// A card produced by on-device OCR that the user has not saved yet.
class DraftCard {
  final String id;
  final CardSource source;
  final String sourceRef;
  final String question;
  final String answer;
  final bool selected;

  const DraftCard({
    required this.id,
    required this.source,
    required this.sourceRef,
    required this.question,
    required this.answer,
    this.selected = true,
  });

  DraftCard copyWith({bool? selected}) {
    return DraftCard(
      id: id,
      source: source,
      sourceRef: sourceRef,
      question: question,
      answer: answer,
      selected: selected ?? this.selected,
    );
  }
}
