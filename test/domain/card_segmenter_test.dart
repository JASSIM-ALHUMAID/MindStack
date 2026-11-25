import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/card_segmenter.dart';
import 'package:mindstack/domain/text_recognizer.dart';

List<CardSegment> segment(String text) =>
    const CardSegmenter().segment([RecognizedBlock(text)]);

void main() {
  group('labelled pairs', () {
    test('one Q/A pair on two lines', () {
      expect(
        segment('Q: What is the powerhouse of the cell?\nA: The mitochondria'),
        const [
          CardSegment(
            question: 'What is the powerhouse of the cell?',
            answer: 'The mitochondria',
          ),
        ],
      );
    });

    test('a wrapped question and answer keep their words', () {
      expect(
        segment(
          'Q: What are the two stages\nof photosynthesis?\n'
          'A: Light reactions\nand the Calvin cycle',
        ),
        const [
          CardSegment(
            question: 'What are the two stages of photosynthesis?',
            answer: 'Light reactions\nand the Calvin cycle',
          ),
        ],
      );
    });

    test('several pairs in one block stay in order', () {
      expect(
        segment('Q: What is X?\nA: Y\nQ: What is Z?\nA: W'),
        const [
          CardSegment(question: 'What is X?', answer: 'Y'),
          CardSegment(question: 'What is Z?', answer: 'W'),
        ],
      );
    });

    test('spelled-out labels are case-insensitive', () {
      expect(
        segment('question: What is X?\nanswer: Y'),
        const [CardSegment(question: 'What is X?', answer: 'Y')],
      );
    });

    test('a question label with no answer is dropped', () {
      expect(segment('Q: What is X?'), isEmpty);
    });

    test('an answer label with no question is dropped', () {
      expect(segment('A: Y'), isEmpty);
    });

    test('a dotted Q label is accepted', () {
      expect(
        segment('Q. What is X?\nA: Y'),
        const [CardSegment(question: 'What is X?', answer: 'Y')],
      );
    });

    test('multiple-choice options are not an answer', () {
      expect(
        segment('Q. Which is correct?\nA. First option\nB. Second option'),
        isEmpty,
      );
    });

    test('unlabelled multiple-choice options are not an answer', () {
      expect(
        segment(
          'Which of the following is a programming language?\n'
          'A. Python\nB. HTML\nC. CSS',
        ),
        isEmpty,
      );
    });

    test('a labelled multiple-choice answer keeps options in the question', () {
      expect(
        segment('Q: Which is correct?\nA. First\nB. Second\nAnswer: B'),
        const [
          CardSegment(
            question: 'Which is correct?\nA. First\nB. Second',
            answer: 'B',
          ),
        ],
      );
    });
  });

  group('question lines', () {
    test('a question line followed by a paragraph', () {
      expect(
        segment('What is osmosis?\nThe movement of water across a membrane.'),
        const [
          CardSegment(
            question: 'What is osmosis?',
            answer: 'The movement of water across a membrane.',
          ),
        ],
      );
    });

    test('bullets are stripped from the answer', () {
      expect(
        segment(
          'What are the three types of memory?\n'
          '• Sensory\n• Working\n• Long-term',
        ),
        const [
          CardSegment(
            question: 'What are the three types of memory?',
            answer: 'Sensory\nWorking\nLong-term',
          ),
        ],
      );
    });

    test('numbered steps are stripped from the answer', () {
      expect(
        segment('What are the steps?\n1. First\n2. Second'),
        const [
          CardSegment(question: 'What are the steps?', answer: 'First\nSecond'),
        ],
      );
    });

    test('an unanswered question line is dropped', () {
      expect(segment('What is osmosis?'), isEmpty);
    });

    test('a one-word question is dropped as noise', () {
      expect(segment('Why?\nBecause.'), isEmpty);
    });

    test('two question lines make two cards', () {
      expect(
        segment('What is X?\nY\nWhat is Z?\nW'),
        const [
          CardSegment(question: 'What is X?', answer: 'Y'),
          CardSegment(question: 'What is Z?', answer: 'W'),
        ],
      );
    });

    test('a question mark inside a labelled answer stays in the answer', () {
      expect(
        segment(
          'Q: What are the causes of inflation?\n'
          'A: Demand-pull inflation.\n'
          'Is cost-push inflation a cause?\n'
          'Yes.',
        ),
        const [
          CardSegment(
            question: 'What are the causes of inflation?',
            answer:
                'Demand-pull inflation.\n'
                'Is cost-push inflation a cause?\n'
                'Yes.',
          ),
        ],
      );
    });

    test('a question mark inside an unlabelled answer stays in the answer', () {
      expect(
        segment(
          'What is the Socratic method?\n'
          'A method of inquiry. Does it work?',
        ),
        const [
          CardSegment(
            question: 'What is the Socratic method?',
            answer: 'A method of inquiry. Does it work?',
          ),
        ],
      );
      expect(
        segment('What is a permalink?\nSee https://example.com?'),
        const [
          CardSegment(
            question: 'What is a permalink?',
            answer: 'See https://example.com?',
          ),
        ],
      );
    });
  });

  group('blocks, noise and normalisation', () {
    test('empty input yields no cards', () {
      expect(const CardSegmenter().segment(const []), isEmpty);
      expect(segment(''), isEmpty);
    });

    test('blocks are read in order and an answer can cross a block', () {
      expect(
        const CardSegmenter().segment(const [
          RecognizedBlock('What is X?\nFirst line.'),
          RecognizedBlock('Second line.'),
        ]),
        const [
          CardSegment(
            question: 'What is X?',
            answer: 'First line.\nSecond line.',
          ),
        ],
      );
    });

    test('noise without a prompt yields no cards', () {
      expect(segment('12\nPage 3 of 20\n3 / 20\n•••\nChapter 4: Memory'), isEmpty);
    });

    test('page furniture never becomes an answer', () {
      const footers = [
        '12',
        '12.',
        '12)',
        'Page 3 of 20',
        'Slide 4',
        'Slide 4 of 20',
        '3 / 20',
        'p. 3',
        '- 12 -',
      ];
      for (final footer in footers) {
        expect(segment('What is osmosis?\n$footer'), isEmpty, reason: footer);
      }
      expect(
        segment('What is osmosis?\nThe movement of water.\nSlide 4'),
        const [
          CardSegment(
            question: 'What is osmosis?',
            answer: 'The movement of water.',
          ),
        ],
      );
    });

    test('tabs, CRLF and repeated spaces are normalised', () {
      expect(
        segment('Q:   What   is\tX?\r\nA:\tY'),
        const [CardSegment(question: 'What is X?', answer: 'Y')],
      );
    });

    test('duplicate pairs are kept once', () {
      expect(
        segment('Q: X?\nA: Y\nQ: X?\nA: Y'),
        const [CardSegment(question: 'X?', answer: 'Y')],
      );
    });
  });
}
