import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/card_segmenter.dart';
import 'package:mindstack/domain/pdf_pages.dart';
import 'package:mindstack/domain/text_recognizer.dart';

const segmenter = CardSegmenter();
const preparer = PdfPagePreparer(segmenter);

/// One page per string, numbered from 1, each read as a single block
List<PdfCardUnit> prepare(List<String> pages, {List<int>? numbers}) =>
    preparer.prepare([
      for (var i = 0; i < pages.length; i++)
        PdfPageText(numbers?[i] ?? i + 1, [RecognizedBlock(pages[i])]),
    ]);

String textOf(PdfCardUnit unit) => unit.blocks.map((b) => b.text).join('\n');

List<CardSegment> cardsOf(List<PdfCardUnit> units) => [
  for (final unit in units) ...segmenter.segment(unit.blocks),
];

void main() {
  group('units', () {
    test('each page is its own unit, labelled by page', () {
      final units = prepare(['Q: What is X?\nA: Y', 'Q: What is Z?\nA: W']);

      expect(units.map((u) => u.label), ['Page 1', 'Page 2']);
      expect(cardsOf(units), const [
        CardSegment(question: 'What is X?', answer: 'Y'),
        CardSegment(question: 'What is Z?', answer: 'W'),
      ]);
    });

    test('blank lines and empty pages are dropped', () {
      final units = prepare(['Title\n\n  \nQ: What is X?\nA: Y', '']);

      expect(textOf(units.first), 'Title\nQ: What is X?\nA: Y');
      expect(units.last.blocks, isEmpty);
    });

    test("a page's title never reaches the previous page's answer", () {
      final units = prepare([
        'What are the three types of memory?\n• Sensory\n• Working',
        'MCQ · four choices\nWhich is a language?\nA. HTML\nB. Python\nAnswer: B',
      ]);

      expect(cardsOf(units), const [
        CardSegment(
          question: 'What are the three types of memory?',
          answer: 'Sensory\nWorking',
        ),
        CardSegment(
          question: 'Which is a language?\nA. HTML\nB. Python',
          answer: 'B. Python',
        ),
      ]);
    });
  });

  group('hyphenated line ends', () {
    final softHyphen = String.fromCharCode(0xAD);

    test('a soft hyphen at a line end joins the word', () {
      final units = prepare([
        'Q: What is the powerhouse of the cell?\nA: The mito$softHyphen\nchondria',
      ]);

      expect(cardsOf(units).single.answer, 'The mitochondria');
    });

    test('a visible hyphen is kept and the lines are joined', () {
      final units = prepare([
        'Q: What is long-\nterm memory?\nA: A store that lasts',
      ]);

      expect(cardsOf(units).single.question, 'What is long-term memory?');
    });

    test('a hyphen before a capital or a choice does not join', () {
      final units = prepare([
        'Pros and cons -\nnot joined\nTop-\nDown\nWhich is it?\nA. x-\nb) y',
      ]);

      expect(
        textOf(units.single),
        'Pros and cons -\nnot joined\nTop-\nDown\nWhich is it?\nA. x-\nb) y',
      );
    });
  });

  group('repeated headers and footers', () {
    test('a footer on every page is dropped even with page numbers', () {
      final units = prepare([
        for (var page = 1; page <= 4; page++)
          'SWE 463 · Lecture 4\nWhat is X$page?\n• Y$page\nKFUPM · Slide $page',
      ]);

      expect(cardsOf(units), [
        for (var page = 1; page <= 4; page++)
          CardSegment(question: 'What is X$page?', answer: 'Y$page'),
      ]);
    });

    test('a line on at least half of the pages is dropped', () {
      final units = prepare([
        'Course notes\nQ: What is A?\nA: 1',
        'Course notes\nQ: What is B?\nA: 2',
        'Course notes\nQ: What is C?\nA: 3',
        'Q: What is D?\nA: 4',
        'Q: What is E?\nA: 5',
        'Q: What is F?\nA: 6',
      ]);

      expect(units.every((u) => !textOf(u).contains('Course notes')), isTrue);
    });

    test('a line on fewer than half of the pages is kept', () {
      final units = prepare([
        'Course notes\nQ: What is A?\nA: 1',
        'Course notes\nQ: What is B?\nA: 2',
        'Course notes\nQ: What is C?\nA: 3',
        'Q: What is D?\nA: 4',
        'Q: What is E?\nA: 5',
        'Q: What is F?\nA: 6',
        'Q: What is G?\nA: 7',
      ]);

      expect(textOf(units.first), startsWith('Course notes'));
    });

    test('nothing is dropped from fewer than three pages', () {
      final units = prepare([
        'Course notes\nQ: What is A?\nA: 1',
        'Course notes\nQ: What is B?\nA: 2',
      ]);

      expect(textOf(units.first), startsWith('Course notes'));
    });

    test('repeated answers, choices and one-word lines are kept', () {
      final units = prepare([
        for (var page = 1; page <= 4; page++)
          'Is X$page true?\nTrue\nWhich one $page?\nA. Yes\nB. No\nAnswer: A',
      ]);

      expect(cardsOf(units), [
        for (var page = 1; page <= 4; page++) ...[
          CardSegment(question: 'Is X$page true?', answer: 'True'),
          CardSegment(
            question: 'Which one $page?\nA. Yes\nB. No',
            answer: 'A. Yes',
          ),
        ],
      ]);
    });

    test('a repeated line in the middle of a page is kept', () {
      final units = prepare([
        for (var page = 1; page <= 4; page++)
          'Title $page\nHeading $page\nSee the lab sheet\nBody $page\nEnd $page',
      ]);

      expect(
        units.every((u) => textOf(u).contains('See the lab sheet')),
        isTrue,
      );
    });
  });

  group('a question continued on the next page', () {
    test('the answer page joins the question page', () {
      final units = prepare([
        'Quiz\nQ: What is working memory?',
        'Answer slide\nA: A small store\nQ: What is Z?\nA: W',
      ]);

      expect(units.single.label, 'Pages 1–2');
      expect(textOf(units.single), isNot(contains('Answer slide')));
      expect(cardsOf(units), const [
        CardSegment(
          question: 'What is working memory?',
          answer: 'A small store',
        ),
        CardSegment(question: 'What is Z?', answer: 'W'),
      ]);
    });

    test('an open question line takes an Answer label on the next page', () {
      final units = prepare([
        'What are the three types of memory?',
        'Answer: Sensory, working and long-term',
      ]);

      expect(cardsOf(units), const [
        CardSegment(
          question: 'What are the three types of memory?',
          answer: 'Sensory, working and long-term',
        ),
      ]);
    });

    test('an answered page is not joined', () {
      final units = prepare(['Q: What is X?\nA: Y', 'A: stray answer']);

      expect(units.map((u) => u.label), ['Page 1', 'Page 2']);
      expect(cardsOf(units), const [
        CardSegment(question: 'What is X?', answer: 'Y'),
      ]);
    });

    test('a next page that starts with a question is not joined', () {
      final units = prepare(['Q: What is X?', 'Q: What is Z?\nA: W']);

      expect(units.map((u) => u.label), ['Page 1', 'Page 2']);
    });

    test('pages are joined only when they are next to each other', () {
      final units = prepare(['Q: What is X?', 'A: Y'], numbers: [1, 3]);

      expect(units.map((u) => u.label), ['Page 1', 'Page 3']);
      expect(cardsOf(units), isEmpty);
    });

    test('a chain of open questions joins three pages', () {
      final units = prepare(['Q: What is X?', 'A: Y\nQ: What is Z?', 'A: W']);

      expect(units.single.label, 'Pages 1–3');
      expect(cardsOf(units), const [
        CardSegment(question: 'What is X?', answer: 'Y'),
        CardSegment(question: 'What is Z?', answer: 'W'),
      ]);
    });
  });
}
