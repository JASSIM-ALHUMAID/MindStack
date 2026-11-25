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
/// they do not give a card a prompt, so the draft would be noise. A run of
/// multiple-choice options belongs to the question, never to the answer.
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
  static final _pageNumber = RegExp(r'^(?:[-–—]\s*)?\d{1,4}(?:\s*[-–—])?$');
  static final _slideNumber = RegExp(r'^\d+\s*/\s*\d+$');
  static final _pageLabel = RegExp(
    r'^(?:page|pg\.?|p\.)\s*\d+(\s+of\s+\d+)?$',
    caseSensitive: false,
  );
  static final _slideLabel = RegExp(
    r'^slide\s+\d+(\s+of\s+\d+)?$',
    caseSensitive: false,
  );
  static final _punctuatedNumber = RegExp(r'^\d{1,4}[.)]$');
  static final _option = RegExp(r'^\(?[A-Ea-e][.)]\s+\S');
  static final _questionStart = RegExp(
    r'^(?:what|why|how|when|where|who|whom|whose|which|explain|define|describe|list|name|give|state|calculate)\b',
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
    final cleaned = <({String text, int block})>[];
    for (var block = 0; block < blocks.length; block++) {
      final text = blocks[block].text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      for (final rawLine in text.split('\n')) {
        final line = _clean(rawLine);
        if (line != null) cleaned.add((text: line, block: block));
      }
    }
    final lines = [
      for (var i = 0; i < cleaned.length; i++)
        _Line(
          cleaned[i].text,
          block: cleaned[i].block,
          isOption: _inOptionRun(cleaned, i),
        ),
    ];

    final segments = <CardSegment>[];
    final emitted = <String>{};
    String? question;
    final answer = <String>[];
    var collectingQuestion = false;
    var collectingAnswer = false;
    var answerFromLabel = false;

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
      answerFromLabel = false;
    }

    var previousBlock = -1;
    for (final line in lines) {
      final startsBlock = line.block != previousBlock;
      previousBlock = line.block;

      if (line.isOption) {
        final current = question;
        if (current == null) continue;
        question = current.isEmpty ? line.text : '$current\n${line.text}';
        continue;
      }

      final questionLabel = _questionLabel.firstMatch(line.text);
      if (questionLabel != null) {
        flush();
        question = line.text.substring(questionLabel.end).trim();
        collectingQuestion = true;
        continue;
      }

      final answerLabel = _answerLabel.firstMatch(line.text);
      if (answerLabel != null) {
        if (question == null) continue;
        answer.add(line.text.substring(answerLabel.end).trim());
        collectingQuestion = false;
        collectingAnswer = true;
        answerFromLabel = true;
        continue;
      }

      final isQuestion = line.text.endsWith('?');
      if (collectingQuestion) {
        final current = question?.trim() ?? '';
        if (isQuestion && current.endsWith('?')) {
          // The previous question already ended; this line is a new one
          flush();
          question = line.text;
          collectingAnswer = true;
        } else {
          question = '$current ${line.text}'.trim();
        }
        continue;
      }

      if (collectingAnswer && isQuestion) {
        final startsQuestion = startsBlock ||
            (!answerFromLabel && _questionStart.hasMatch(line.text));
        if (startsQuestion) {
          flush();
          question = line.text;
          collectingAnswer = true;
        } else {
          answer.add(line.text);
        }
        continue;
      }

      if (isQuestion && line.text.split(_whitespace).length >= 2) {
        flush();
        question = line.text;
        collectingAnswer = true;
        continue;
      }

      if (collectingAnswer) answer.add(line.text);
    }

    flush();
    return segments;
  }

  /// True when the option at [index] belongs to a run of at least two in
  /// the same block.
  bool _inOptionRun(List<({String text, int block})> lines, int index) {
    final line = lines[index];
    if (!_option.hasMatch(line.text)) return false;
    final before = index > 0 &&
        lines[index - 1].block == line.block &&
        _option.hasMatch(lines[index - 1].text);
    final after = index + 1 < lines.length &&
        lines[index + 1].block == line.block &&
        _option.hasMatch(lines[index + 1].text);
    return before || after;
  }

  /// Normalises [raw] and returns null for blank lines and page furniture
  String? _clean(String raw) {
    final cleaned = raw.replaceAll('\t', ' ').replaceAll(_spaces, ' ').trim();
    if (cleaned.isEmpty) return null;
    if (_isFurniture(cleaned)) return null;

    final line = cleaned.replaceFirst(_bullet, '').trim();
    if (line.isEmpty || !_hasLetterOrDigit.hasMatch(line)) return null;
    if (_isFurniture(line)) return null;
    return line;
  }

  bool _isFurniture(String line) =>
      _pageNumber.hasMatch(line) ||
      _slideNumber.hasMatch(line) ||
      _pageLabel.hasMatch(line) ||
      _slideLabel.hasMatch(line) ||
      _punctuatedNumber.hasMatch(line);
}

/// A cleaned line and whether it belongs to a multiple-choice option run
final class _Line {
  const _Line(this.text, {required this.block, required this.isOption});

  final String text;
  final int block;
  final bool isOption;
}
