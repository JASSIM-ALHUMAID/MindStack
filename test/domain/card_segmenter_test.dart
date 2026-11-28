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

    test('an Ans label is accepted in any case', () {
      expect(segment('Q: What is X?\nAns: Y\nQ: What is Z?\nans: W'), const [
        CardSegment(question: 'What is X?', answer: 'Y'),
        CardSegment(question: 'What is Z?', answer: 'W'),
      ]);
    });

    test('an Ans label resolves an MCQ letter', () {
      expect(segment('Which is a language?\nA. HTML\nB. Python\nAns: B'), const [
        CardSegment(
          question: 'Which is a language?\nA. HTML\nB. Python',
          answer: 'B. Python',
        ),
      ]);
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
            answer: 'B. Second',
          ),
        ],
      );
    });

    test('an MCQ answer letter maps to the chosen choice', () {
      expect(
        segment(
          'Which of the following is a programming language?\n'
          'A. HTML\nB. Python\nC. CSS\nAnswer: B',
        ),
        const [
          CardSegment(
            question:
                'Which of the following is a programming language?\n'
                'A. HTML\nB. Python\nC. CSS',
            answer: 'B. Python',
          ),
        ],
      );
    });

    test('a four-choice MCQ maps the last choice', () {
      expect(
        segment(
          'Which number is even?\n'
          'A. 3\nB. 5\nC. 7\nD. 8\nanswer: d',
        ),
        const [
          CardSegment(
            question: 'Which number is even?\nA. 3\nB. 5\nC. 7\nD. 8',
            answer: 'D. 8',
          ),
        ],
      );
    });

    test('MCQ choices can cross block boundaries', () {
      expect(
        const CardSegmenter().segment(const [
          RecognizedBlock('Which is a markup language?'),
          RecognizedBlock('A. HTML'),
          RecognizedBlock('B. Python'),
          RecognizedBlock('Answer: A'),
        ]),
        const [
          CardSegment(
            question: 'Which is a markup language?\nA. HTML\nB. Python',
            answer: 'A. HTML',
          ),
        ],
      );
    });

    test('lowercase MCQ choices map too', () {
      expect(
        segment(
          'Which is a markup language?\n'
          'a) HTML\nb) Python\nAnswer: b',
        ),
        const [
          CardSegment(
            question: 'Which is a markup language?\na) HTML\nb) Python',
            answer: 'b) Python',
          ),
        ],
      );
    });

    test('an explicit MCQ answer text is kept', () {
      expect(
        segment(
          'Which is a markup language?\n'
          'A. HTML\nB. Python\nAnswer: HTML',
        ),
        const [
          CardSegment(
            question: 'Which is a markup language?\nA. HTML\nB. Python',
            answer: 'HTML',
          ),
        ],
      );
    });

    test('an answer letter outside the choices stays raw', () {
      expect(
        segment(
          'Which is a markup language?\n'
          'A. HTML\nB. Python\nAnswer: E',
        ),
        const [
          CardSegment(
            question: 'Which is a markup language?\nA. HTML\nB. Python',
            answer: 'E',
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

  group('line and page checks', () {
    const segmenter = CardSegmenter();

    test('card lines are labels, choices and questions', () {
      for (final line in [
        'Q: What is X?',
        'Answer: B',
        'Ans: Y',
        'b) Python',
        '• What are the three types of memory?',
      ]) {
        expect(segmenter.isCardLine(line), isTrue, reason: line);
      }
      for (final line in ['SWE 463 · Lecture 4', 'Chapter 4: Memory', '12']) {
        expect(segmenter.isCardLine(line), isFalse, reason: line);
      }
    });

    test('answer lines need an answer label', () {
      expect(segmenter.isAnswerLine('A: The mitochondria'), isTrue);
      expect(segmenter.isAnswerLine('Ans: B'), isTrue);
      expect(segmenter.isAnswerLine('A. HTML'), isFalse);
      expect(segmenter.isAnswerLine('Answers vary'), isFalse);
    });

    List<RecognizedBlock> blocks(String text) => [RecognizedBlock(text)];

    test('an unanswered question is open', () {
      expect(
        segmenter.endsWithOpenQuestion(blocks('Recap\nQ: What is X?\n12')),
        isTrue,
      );
      expect(
        segmenter.endsWithOpenQuestion(blocks('What are the three types?')),
        isTrue,
      );
      expect(
        segmenter.endsWithOpenQuestion(
          blocks('Which is a language?\nA. HTML\nB. Python'),
        ),
        isTrue,
      );
    });

    test('an answered question or plain text is not open', () {
      expect(
        segmenter.endsWithOpenQuestion(blocks('Q: What is X?\nA: Y')),
        isFalse,
      );
      expect(
        segmenter.endsWithOpenQuestion(blocks('What is X?\n• Y\n• Z')),
        isFalse,
      );
      expect(
        segmenter.endsWithOpenQuestion(blocks('Chapter 4: Memory')),
        isFalse,
      );
    });
  });
}
