import 'dart:convert';

import 'enums.dart';

final class MindstackCard {
  const MindstackCard({
    required this.question,
    required this.answer,
    this.source = CardSource.manual,
  });

  final String question;
  final String answer;

  /// Original source on the sharer's phone.
  final CardSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindstackCard &&
          other.question == question &&
          other.answer == answer &&
          other.source == source;

  @override
  int get hashCode => Object.hash(question, answer, source);

  @override
  String toString() =>
      'MindstackCard(question: $question, answer: $answer, '
      'source: ${source.name})';
}

/// A deck shared as a JSON file. It has no scheduling fields, so whoever
/// imports it starts fresh.
final class MindstackFile {
  const MindstackFile({required this.deckTitle, required this.cards});

  static const extension = '.mindstack';

  final String deckTitle;
  final List<MindstackCard> cards;

  /// Throws [FormatException] with a user-readable message if [text] is not
  /// a valid deck.
  factory MindstackFile.parse(String text) {
    if (text.trim().isEmpty) {
      throw const FormatException('The file is empty.');
    }
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const FormatException("This isn't a MindStack deck file.");
    }
    if (root is! Map<String, Object?>) {
      throw const FormatException("This isn't a MindStack deck file.");
    }

    final title = _text(root['deckTitle']);
    if (title == null) {
      throw const FormatException('The deck has no title.');
    }

    final rawCards = root['cards'];
    if (rawCards is! List<Object?>) {
      throw const FormatException('The file has no list of cards.');
    }
    if (rawCards.isEmpty) {
      throw const FormatException('The deck has no cards.');
    }

    final cards = <MindstackCard>[];
    for (var i = 0; i < rawCards.length; i++) {
      final number = i + 1;
      final raw = rawCards[i];
      if (raw is! Map<String, Object?>) {
        throw FormatException('Card $number is not a card.');
      }
      final question = _text(raw['question']);
      if (question == null) {
        throw FormatException('Card $number has no question.');
      }
      final answer = _text(raw['answer']);
      if (answer == null) {
        throw FormatException('Card $number has no answer.');
      }
      cards.add(
        MindstackCard(
          question: question,
          answer: answer,
          source: _source(raw['source']),
        ),
      );
    }
    return MindstackFile(deckTitle: title, cards: List.unmodifiable(cards));
  }

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'deckTitle': deckTitle,
    'cards': [
      for (final c in cards)
        {'question': c.question, 'answer': c.answer, 'source': c.source.name},
    ],
  });

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static CardSource _source(Object? value) {
    for (final s in CardSource.values) {
      if (s.name == value) return s;
    }
    // Missing or unknown (e.g. from a newer app version): still import.
    return CardSource.manual;
  }
}
