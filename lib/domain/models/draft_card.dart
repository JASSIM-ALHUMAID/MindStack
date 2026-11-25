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
    this.position,
  });

  /// Stable unique id.
  final String id;

  /// Where the text came from (slide, PDF, photo, shared file).
  final CardSource source;

  /// Human-readable origin, for example "Page 2".
  final String sourceRef;

  /// The recognised question text.
  final String question;

  /// The recognised answer text.
  final String answer;

  /// Whether the user has ticked this draft for saving.
  final bool selected;

  /// Place in the Inbox list, or null for a draft that is not stored yet.
  /// A stored draft re-inserted with its position returns to the same place.
  final int? position;

  /// A copy with [selected] replaced; every other field is kept.
  DraftCard copyWith({bool? selected}) {
    return DraftCard(
      id: id,
      source: source,
      sourceRef: sourceRef,
      question: question,
      answer: answer,
      selected: selected ?? this.selected,
      position: position,
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
          other.selected == selected &&
          other.position == position;

  @override
  int get hashCode =>
      Object.hash(id, source, sourceRef, question, answer, selected, position);

  @override
  String toString() =>
      'DraftCard(id: $id, source: ${source.name}, '
      'sourceRef: $sourceRef, question: $question, answer: $answer, '
      'selected: $selected, position: $position)';
}
