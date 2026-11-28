import 'dart:math';

import 'card_segmenter.dart';
import 'text_recognizer.dart';

/// Text read from one PDF page, from its text layer or by OCR
final class PdfPageText {
  const PdfPageText(this.pageNumber, this.blocks);

  /// Starts at 1
  final int pageNumber;

  final List<RecognizedBlock> blocks;
}

/// One page, or a question page and its answer pages, segmented together
final class PdfCardUnit {
  const PdfCardUnit({
    required this.firstPage,
    required this.lastPage,
    required this.blocks,
  });

  final int firstPage;
  final int lastPage;
  final List<RecognizedBlock> blocks;

  /// Shown on each draft, for example "Page 4" or "Pages 4–5"
  String get label =>
      firstPage == lastPage ? 'Page $firstPage' : 'Pages $firstPage–$lastPage';
}

/// Gets PDF pages ready for the [CardSegmenter].
///
/// - A word broken by a hyphen at a line end is joined again. A soft hyphen
///   is removed; a visible one is kept, because `long-term` cannot be told
///   from `mito-chondria` without a dictionary.
/// - A header or footer on at least half of the pages (and at least three)
///   is dropped, so it never ends up in an answer.
/// - A page that ends with an unanswered question is joined with the next
///   page when that page starts with the answer.
///
/// Pages stay separate otherwise, so one page's title cannot leak into the
/// previous page's answer.
final class PdfPagePreparer {
  const PdfPagePreparer(this._segmenter);

  final CardSegmenter _segmenter;

  static const _minRepeatedPages = 3;

  /// Lines at each end of a page that may be a header or footer
  static const _edgeLines = 2;

  static final _softHyphens = {0xAD, 0x02};
  static final _visibleHyphenEnd = RegExp(r'[A-Za-z]-$');
  static final _startsLowercase = RegExp(r'^[a-z]');
  static final _number = RegExp(r'\b\d+\b');
  static final _bullet = RegExp(r'^(?:[-*•·–—]|\d+[.)])\s');
  static final _whitespace = RegExp(r'\s+');

  List<PdfCardUnit> prepare(List<PdfPageText> pages) {
    final cleaned = [
      for (final page in pages)
        _Page(page.pageNumber, [
          for (final block in page.blocks) _joinHyphens(_lines(block.text)),
        ]),
    ];
    _dropRepeatedEdges(cleaned);
    return _units(cleaned);
  }

  List<String> _lines(String text) => [
    for (final line
        in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  List<String> _joinHyphens(List<String> lines) {
    final joined = <String>[];
    for (final line in lines) {
      final previous = joined.isEmpty ? null : joined.last;
      final word = previous == null ? null : _joinWord(previous, line);
      if (word != null) {
        joined[joined.length - 1] = word;
      } else {
        joined.add(line);
      }
    }
    return joined;
  }

  String? _joinWord(String previous, String next) {
    // A wrapped question ends in "?" too, so only a label or choice blocks it
    final startsCard = _segmenter.isCardLine(next) && !next.endsWith('?');
    if (!_startsLowercase.hasMatch(next) || startsCard) return null;
    final last = previous.codeUnitAt(previous.length - 1);
    if (_softHyphens.contains(last)) {
      return previous.substring(0, previous.length - 1) + next;
    }
    if (_visibleHyphenEnd.hasMatch(previous)) return previous + next;
    return null;
  }

  void _dropRepeatedEdges(List<_Page> pages) {
    if (pages.length < _minRepeatedPages) return;
    final needed = max(_minRepeatedPages, (pages.length / 2).ceil());
    final counts = <String, int>{};
    for (final page in pages) {
      final keys = {
        for (final line in page.edges(_edgeLines))
          if (_mayRepeat(line)) _key(line),
      };
      for (final key in keys) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final repeated = {
      for (final entry in counts.entries)
        if (entry.value >= needed) entry.key,
    };
    if (repeated.isEmpty) return;
    for (final page in pages) {
      page.removeEdges(
        _edgeLines,
        (line) => _mayRepeat(line) && repeated.contains(_key(line)),
      );
    }
  }

  /// Card lines, bullets and single words like "True" may repeat on purpose
  bool _mayRepeat(String line) {
    if (_segmenter.isCardLine(line) || _bullet.hasMatch(line)) return false;
    return line.split(_whitespace).length >= 2 || _number.hasMatch(line);
  }

  /// Page numbers differ from page to page, so numbers are ignored
  String _key(String line) =>
      line.toLowerCase().replaceAll(_number, '#').replaceAll(_whitespace, ' ');

  List<PdfCardUnit> _units(List<_Page> pages) {
    final units = <PdfCardUnit>[];
    var i = 0;
    while (i < pages.length) {
      final first = pages[i].number;
      var last = first;
      var blocks = pages[i].blocks();
      var next = i + 1;
      while (next < pages.length &&
          pages[next].number == last + 1 &&
          _segmenter.endsWithOpenQuestion(blocks)) {
        final answer = _fromAnswer(pages[next]);
        if (answer == null) break;
        blocks = [...blocks, ...answer];
        last = pages[next].number;
        next++;
      }
      units.add(PdfCardUnit(firstPage: first, lastPage: last, blocks: blocks));
      i = next;
    }
    return units;
  }

  /// The page from its first card line on, when that line is an answer
  List<RecognizedBlock>? _fromAnswer(_Page page) {
    for (var b = 0; b < page.lines.length; b++) {
      final block = page.lines[b];
      for (var l = 0; l < block.length; l++) {
        if (!_segmenter.isCardLine(block[l])) continue;
        if (!_segmenter.isAnswerLine(block[l])) return null;
        return [
          RecognizedBlock(block.sublist(l).join('\n')),
          for (final rest in page.lines.skip(b + 1))
            if (rest.isNotEmpty) RecognizedBlock(rest.join('\n')),
        ];
      }
    }
    return null;
  }
}

/// A page as lines per block, edited in place while preparing
final class _Page {
  _Page(this.number, this.lines);

  final int number;
  final List<List<String>> lines;

  List<RecognizedBlock> blocks() => [
    for (final block in lines)
      if (block.isNotEmpty) RecognizedBlock(block.join('\n')),
  ];

  /// The first and last [count] lines of the page, across blocks
  Iterable<String> edges(int count) sync* {
    final all = [for (final block in lines) ...block];
    for (var i = 0; i < all.length; i++) {
      if (i < count || i >= all.length - count) yield all[i];
    }
  }

  void removeEdges(int count, bool Function(String line) test) {
    final total = lines.fold(0, (sum, block) => sum + block.length);
    var index = 0;
    for (final block in lines) {
      block.removeWhere((line) {
        final edge = index < count || index >= total - count;
        index++;
        return edge && test(line);
      });
    }
  }
}
