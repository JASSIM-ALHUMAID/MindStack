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

    test('page furniture yields no cards', () {
      expect(
        segment('12\nPage 3 of 20\n3 / 20\n•••\nChapter 4: Memory'),
        isEmpty,
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
