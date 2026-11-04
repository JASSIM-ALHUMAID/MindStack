import '../enums.dart';

/// A card produced by on-device OCR that the user has not saved yet.
class DraftCard {
  /// Creates a draft; drafts start selected.
  const DraftCard({
    required this.id,
    required this.source,
    required this.sourceRef,
    required this.question,
    required this.answer,
    this.selected = true,
  });

  final String id;
  final CardSource source;
  final String sourceRef;
  final String question;
  final String answer;
  final bool selected;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftCard &&
          other.id == id &&
          other.source == source &&
          other.sourceRef == sourceRef &&
          other.question == question &&
          other.answer == answer &&
          other.selected == selected;

  @override
  int get hashCode =>
      Object.hash(id, source, sourceRef, question, answer, selected);

  @override
  String toString() =>
      'DraftCard(id: $id, source: ${source.name}, '
      'sourceRef: $sourceRef, question: $question, answer: $answer, '
      'selected: $selected)';
}
