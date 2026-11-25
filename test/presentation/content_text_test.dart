import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/presentation/widgets/content_text.dart';

void main() {
  group('textDirectionOf', () {
    test('Arabic and Hebrew are right to left', () {
      expect(
        textDirectionOf('ما هو الـ Widget في Flutter؟'),
        TextDirection.rtl,
      );
      expect(textDirectionOf('שלום'), TextDirection.rtl);
    });

    test('Latin text is left to right', () {
      expect(textDirectionOf('What is a Widget?'), TextDirection.ltr);
    });

    test('the first letter decides mixed text', () {
      expect(
        textDirectionOf('مراجعة · Unicode & long text'),
        TextDirection.rtl,
      );
      expect(textDirectionOf('Flutter في'), TextDirection.ltr);
    });

    test('digits, symbols and emoji before the first letter are skipped', () {
      expect(textDirectionOf('1. (مرحبا)'), TextDirection.rtl);
      expect(textDirectionOf('🙂 "Hi"'), TextDirection.ltr);
    });

    test('text without letters has no direction of its own', () {
      expect(textDirectionOf(''), isNull);
      expect(textDirectionOf('123 + 4 🙂'), isNull);
    });
  });

  group('isolateDirection', () {
    // The marks are invisible, so they are built from their code points.
    final open = String.fromCharCode(0x2068);
    final close = String.fromCharCode(0x2069);

    test('wraps right-to-left text in isolate marks', () {
      expect(
        isolateDirection('أساسيات Flutter'),
        [open, 'أساسيات Flutter', close].join(),
      );
    });

    test('leaves other text unchanged', () {
      expect(isolateDirection('Flutter Widgets'), 'Flutter Widgets');
      expect(isolateDirection('Flutter في'), 'Flutter في');
      expect(isolateDirection(''), '');
    });
  });

  testWidgets('Arabic starts from the right in the English layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ContentText('مرحبا'), ContentText('Hello')],
            ),
          ),
        ),
      ),
    );

    final arabic = tester.widget<Text>(find.text('مرحبا'));
    final english = tester.widget<Text>(find.text('Hello'));
    expect(arabic.textDirection, TextDirection.rtl);
    expect(english.textDirection, TextDirection.ltr);
    expect(tester.getTopRight(find.text('مرحبا')).dx, 400);
    expect(tester.getTopLeft(find.text('Hello')).dx, 0);
  });
}
