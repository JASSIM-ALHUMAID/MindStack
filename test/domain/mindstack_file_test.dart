import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/mindstack_file.dart';

String _fixture(String path) =>
    File('test/fixtures/mindstack/$path').readAsStringSync();

void main() {
  group('valid fixtures', () {
    test('01_flutter_widgets reads the title and all 5 cards in order', () {
      final file = MindstackFile.parse(
        _fixture('valid/01_flutter_widgets.mindstack'),
      );

      expect(file.deckTitle, 'Flutter Widgets');
      expect(file.cards, hasLength(5));
      expect(
        file.cards.first,
        const MindstackCard(
          question: 'What is a Widget?',
          answer: 'The immutable building block of a Flutter UI.',
          source: CardSource.slide,
        ),
      );
      expect(file.cards.last.source, CardSource.photo);
    });

    test('every valid fixture parses', () {
      final dir = Directory('test/fixtures/mindstack/valid');
      final files = dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith(MindstackFile.extension),
      );

      expect(files, isNotEmpty);
      for (final f in files) {
        final parsed = MindstackFile.parse(f.readAsStringSync());
        expect(parsed.cards, isNotEmpty, reason: f.path);
      }
    });

    test('unicode, emoji and newlines survive', () {
      final file = MindstackFile.parse(
        _fixture('valid/05_unicode_and_long_text.mindstack'),
      );
      final again = MindstackFile.parse(file.encode());

      expect(again.deckTitle, file.deckTitle);
      expect(again.cards, file.cards);
    });
  });

  group('invalid fixtures throw FormatException', () {
    final cases = {
      'bad_01_not_json': "This isn't a MindStack deck file.",
      'bad_02_empty_file': 'The file is empty.',
      'bad_03_no_cards_key': 'The file has no list of cards.',
      'bad_04_empty_cards': 'The deck has no cards.',
      'bad_05_card_missing_answer': 'Card 1 has no answer.',
      'bad_06_truncated_json': "This isn't a MindStack deck file.",
    };
    for (final MapEntry(key: name, value: message) in cases.entries) {
      test(name, () {
        expect(
          () => MindstackFile.parse(_fixture('invalid/$name.mindstack')),
          throwsA(
            isA<FormatException>().having((e) => e.message, 'message', message),
          ),
        );
      });
    }
  });

  group('edge cases', () {
    test('a JSON list instead of an object is rejected', () {
      expect(() => MindstackFile.parse('[]'), throwsFormatException);
    });

    test('a blank title is rejected', () {
      expect(
        () => MindstackFile.parse(
          '{"deckTitle": "  ", "cards": [{"question": "Q", "answer": "A"}]}',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'The deck has no title.',
          ),
        ),
      );
    });

    test('a whitespace-only question names the card number', () {
      expect(
        () => MindstackFile.parse(
          '{"deckTitle": "D", "cards": ['
          '{"question": "Q1", "answer": "A1"},'
          '{"question": "   ", "answer": "A2"}]}',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Card 2 has no question.',
          ),
        ),
      );
    });

    test('text is trimmed and a missing or unknown source becomes manual', () {
      final file = MindstackFile.parse(
        '{"deckTitle": " D ", "cards": ['
        '{"question": " Q1 ", "answer": " A1 "},'
        '{"question": "Q2", "answer": "A2", "source": "hologram"}]}',
      );

      expect(file.deckTitle, 'D');
      expect(file.cards, const [
        MindstackCard(question: 'Q1', answer: 'A1'),
        MindstackCard(question: 'Q2', answer: 'A2'),
      ]);
    });
  });

  test('encode writes no scheduling fields', () {
    final json = const MindstackFile(
      deckTitle: 'D',
      cards: [
        MindstackCard(question: 'Q', answer: 'A', source: CardSource.pdf),
      ],
    ).encode();

    for (final field in ['interval', 'ease', 'due', 'repetitions', 'mastery']) {
      expect(json.toLowerCase(), isNot(contains(field)));
    }
    expect(MindstackFile.parse(json).cards.single.source, CardSource.pdf);
  });
}
