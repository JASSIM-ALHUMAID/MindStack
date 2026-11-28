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
/// A card needs a clear prompt:
/// 1. `Q:`/`Question:` followed by `A:`/`Ans:`/`Answer:`.
/// 2. A question line ending in `?` followed by body lines.
/// 3. Up to four choices A-D followed by an `Answer:`/`Ans:` line.
///
/// Headings, bullets without a question and plain paragraphs are ignored:
/// they do not give a card a prompt, so the draft would be noise. MCQ
/// choices belong to the question; a bare answer letter resolves to the
/// matching choice line.
final class CardSegmenter {
  const CardSegmenter();

  static final _questionLabel = RegExp(
    r'^(?:Q|Question)\s*\d*\s*[:.)]\s*',
    caseSensitive: false,
  );
  static final _answerLabel = RegExp(
    r'^(?:A|Ans|Answer)\s*\d*\s*:\s*',
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
  static final _option = RegExp(r'^\(?[A-Da-d][.)]\s+\S');
  static final _optionLabel = RegExp(r'^\(?([A-Da-d])[.)]');
  static final _bareAnswerLetter = RegExp(r'^\(?([A-Da-d])[.)]?\s*$');
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
  List<CardSegment> segment(List<RecognizedBlock> blocks) =>
      _run(blocks).segments;

  /// Whether [blocks] end with a question that has no answer yet
  bool endsWithOpenQuestion(List<RecognizedBlock> blocks) => _run(blocks).open;

  /// Whether [line] is a Q/A label, an MCQ choice or a question
  bool isCardLine(String line) {
    final cleaned = _clean(line);
    if (cleaned == null) return false;
    return _questionLabel.hasMatch(cleaned) ||
        _answerLabel.hasMatch(cleaned) ||
        _option.hasMatch(cleaned) ||
        cleaned.endsWith('?');
  }

  /// Whether [line] starts with an answer label
  bool isAnswerLine(String line) {
    final cleaned = _clean(line);
    return cleaned != null && _answerLabel.hasMatch(cleaned);
  }

  ({List<CardSegment> segments, bool open}) _run(List<RecognizedBlock> blocks) {
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
    final options = <String, String>{};
    var collectingQuestion = false;
    var collectingAnswer = false;
    var answerFromLabel = false;

    void flush() {
      final q = question?.trim() ?? '';
      final a = _resolveAnswer(answer, options);
      if (q.isNotEmpty && a.isNotEmpty && emitted.add('$q\u0000$a')) {
        segments.add(CardSegment(question: q, answer: a));
      }
      question = null;
      answer.clear();
      options.clear();
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
        final label = _optionLabel.firstMatch(line.text);
        if (label != null) {
          options[label.group(1)!.toUpperCase()] = line.text;
        }
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
        final text = line.text.substring(answerLabel.end).trim();
        if (text.isNotEmpty) answer.add(text);
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

    final last = question;
    final open = last != null && last.trim().isNotEmpty && answer.isEmpty;
    flush();
    return (segments: segments, open: open);
  }

  /// An option counts only when another option is adjacent
  bool _inOptionRun(List<({String text, int block})> lines, int index) {
    if (!_option.hasMatch(lines[index].text)) return false;
    final before = index > 0 && _option.hasMatch(lines[index - 1].text);
    final after = index + 1 < lines.length &&
        _option.hasMatch(lines[index + 1].text);
    return before || after;
  }

  /// Resolves a bare MCQ answer letter to its choice line
  String _resolveAnswer(List<String> answer, Map<String, String> options) {
    final raw = answer.join('\n').trim();
    if (answer.length != 1 || options.isEmpty) return raw;
    final match = _bareAnswerLetter.firstMatch(raw);
    if (match == null) return raw;
    return options[match.group(1)!.toUpperCase()] ?? raw;
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
