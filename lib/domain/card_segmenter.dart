import 'text_recognizer.dart';

/// One question/answer pair found in recognised text
class CardSegment {
  const CardSegment({required this.question, required this.answer});

  final String question;

  final String answer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardSegment &&
          other.question == question &&
          other.answer == answer;

  @override
  int get hashCode => Object.hash(question, answer);

  @override
  String toString() => 'CardSegment(question: $question, answer: $answer)';
}

/// Turns recognised text into question/answer cards.
///
/// Only two shapes become cards:
/// 1. Explicit labels: `Q:`/`Question:` followed by `A:`/`Answer:`.
/// 2. A question line ending in `?` followed by body lines.
///
/// Headings, bullets without a question and plain paragraphs are ignored:
/// they do not give a card a prompt, so the draft would be noise.
final class CardSegmenter {
  const CardSegmenter();

  static final _questionLabel = RegExp(
    r'^(?:Q|Question)\s*\d*\s*[:.)]\s*',
    caseSensitive: false,
  );
  static final _answerLabel = RegExp(
    r'^(?:A|Answer)\s*\d*\s*:\s*',
    caseSensitive: false,
  );
  static final _bullet = RegExp(r'^(?:[-*•·–—]\s+|\d+[.)]\s+)');
  static final _pageNumber = RegExp(r'^\d{1,4}$');
  static final _slideNumber = RegExp(r'^\d+\s*/\s*\d+$');
  static final _pageLabel = RegExp(
    r'^page\s+\d+(\s+of\s+\d+)?$',
    caseSensitive: false,
  );
  static final _hasLetterOrDigit = RegExp(r'[A-Za-z0-9]');
  static final _spaces = RegExp(r' +');
  static final _whitespace = RegExp(r'\s+');

  /// Returns the cards found in [blocks], in reading order.
  ///
  /// Blocks are read in the order given. A question or answer may continue
  /// across a block boundary.
  List<CardSegment> segment(List<RecognizedBlock> blocks) {
    final lines = <String>[];
    for (final block in blocks) {
      final text = block.text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      for (final rawLine in text.split('\n')) {
        final line = _clean(rawLine);
        if (line != null) lines.add(line);
      }
    }

    final segments = <CardSegment>[];
    final emitted = <String>{};
    String? question;
    final answer = <String>[];
    var collectingQuestion = false;
    var collectingAnswer = false;

    void flush() {
      final q = question?.trim() ?? '';
      final a = answer.join('\n').trim();
      if (q.isNotEmpty && a.isNotEmpty && emitted.add('$q\u0000$a')) {
        segments.add(CardSegment(question: q, answer: a));
      }
      question = null;
      answer.clear();
      collectingQuestion = false;
      collectingAnswer = false;
    }

    for (final line in lines) {
      final questionLabel = _questionLabel.firstMatch(line);
      if (questionLabel != null) {
        flush();
        question = line.substring(questionLabel.end).trim();
        collectingQuestion = true;
        continue;
      }

      final answerLabel = _answerLabel.firstMatch(line);
      if (answerLabel != null) {
        if (question == null) continue;
        answer.add(line.substring(answerLabel.end).trim());
        collectingQuestion = false;
        collectingAnswer = true;
        continue;
      }

      final isQuestion = line.endsWith('?');
      if (collectingQuestion) {
        final current = question?.trim() ?? '';
        if (isQuestion && current.endsWith('?')) {
          // The previous question already ended; this line is a new one
          flush();
          question = line;
          collectingAnswer = true;
        } else {
          question = '$current $line'.trim();
        }
        continue;
      }

      if (isQuestion && line.split(_whitespace).length >= 2) {
        flush();
        question = line;
        collectingAnswer = true;
        continue;
      }

      if (collectingAnswer) answer.add(line);
    }

    flush();
    return segments;
  }

  /// Normalises [raw] and returns null for blank lines and page furniture
  String? _clean(String raw) {
    var line = raw.replaceAll('\t', ' ').replaceAll(_spaces, ' ').trim();
    if (line.isEmpty) return null;

    line = line.replaceFirst(_bullet, '').trim();
    if (line.isEmpty || !_hasLetterOrDigit.hasMatch(line)) return null;
    if (_pageNumber.hasMatch(line) ||
        _slideNumber.hasMatch(line) ||
        _pageLabel.hasMatch(line)) {
      return null;
    }
    return line;
  }
}
