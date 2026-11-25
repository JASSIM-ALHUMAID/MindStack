import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/ocr.dart';
import 'package:mindstack/domain/card_segmenter.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/models/draft_card.dart';
import 'package:mindstack/domain/text_recognizer.dart';

import '../support/container.dart';
import '../support/fakes.dart';

void main() {
  final blocks = [
    const RecognizedBlock('Q: What is X?\nA: Y'),
    const RecognizedBlock('What is Z?\nW'),
  ];

  OcrImporter buildImporter({
    TextRecognizer? recognizer,
    FixedClock? clock,
    RecordingLogger? logger,
    SequentialIds? ids,
  }) {
    return OcrImporter(
      recognizer: recognizer ?? FakeTextRecognizer([RecognizedText(blocks)]),
      segmenter: const CardSegmenter(),
      ids: ids ?? SequentialIds(),
      clock: clock ?? FixedClock(DateTime(2026, 11, 25, 10)),
      logger: logger ?? RecordingLogger(),
    );
  }

  test('returns drafts with ids, source and scan time', () async {
    final result = await buildImporter().scan(
      imagePath: '/tmp/slide.png',
      source: CardSource.slide,
      sourceRef: 'Slide 1',
    );

    expect(result, isA<OcrScanSuccess>());
    final success = result as OcrScanSuccess;
    expect(success.scannedAt, DateTime(2026, 11, 25, 10));
    expect(success.drafts, [
      const DraftCard(
        id: 'id-1',
        source: CardSource.slide,
        sourceRef: 'Slide 1',
        question: 'What is X?',
        answer: 'Y',
      ),
      const DraftCard(
        id: 'id-2',
        source: CardSource.slide,
        sourceRef: 'Slide 1',
        question: 'What is Z?',
        answer: 'W',
      ),
    ]);
  });

  test('returns each recogniser failure as a typed failure', () async {
    for (final kind in RecognitionFailureKind.values) {
      final result = await buildImporter(
        recognizer: FakeTextRecognizer([RecognitionFailure(kind)]),
      ).scan(
        imagePath: '/tmp/photo.png',
        source: CardSource.photo,
        sourceRef: 'Photo',
      );

      expect(
        result,
        isA<OcrScanFailure>()
            .having((r) => r.kind, 'kind', kind)
            .having(
              (r) => r.userMessage,
              'message',
              RecognitionFailure(kind).userMessage,
            ),
      );
    }
  });

  test('maps an unexpected throw to engineUnavailable and logs it', () async {
    final logger = RecordingLogger();
    final result = await buildImporter(
      recognizer: FakeTextRecognizer()..queueError(StateError('boom')),
      logger: logger,
    ).scan(
      imagePath: '/tmp/photo.png',
      source: CardSource.photo,
      sourceRef: 'Photo',
    );

    expect(
      result,
      isA<OcrScanFailure>().having(
        (r) => r.kind,
        'kind',
        RecognitionFailureKind.engineUnavailable,
      ),
    );
    expect(logger.errors, hasLength(1));
    expect(logger.errors.single.error, isA<StateError>());
  });

  test('returns an empty success when the text has no card shapes', () async {
    final result = await buildImporter(
      recognizer: FakeTextRecognizer([
        const RecognizedText([RecognizedBlock('Chapter 4: Memory')]),
      ]),
    ).scan(
      imagePath: '/tmp/photo.png',
      source: CardSource.photo,
      sourceRef: 'Photo',
    );

    expect(
      result,
      isA<OcrScanSuccess>().having((r) => r.drafts, 'drafts', isEmpty),
    );
  });

  test('provider wiring uses the injected recogniser, clock and ids', () async {
    final fake = FakeTextRecognizer([
      const RecognizedText([RecognizedBlock('Q: X?\nA: Y')]),
    ]);
    final container = makeContainer(recognizer: fake);

    final result = await container.read(ocrImporterProvider).scan(
      imagePath: '/tmp/page.png',
      source: CardSource.pdf,
      sourceRef: 'Page 2',
    );

    final success = result as OcrScanSuccess;
    expect(success.drafts.single.id, 'id-1');
    expect(success.drafts.single.source, CardSource.pdf);
    expect(success.scannedAt, DateTime(2026, 11, 4, 12));
  });

  test('disposing the provider closes the recogniser', () async {
    final fake = FakeTextRecognizer();
    final container = ProviderContainer(
      overrides: [textRecognizerFactoryProvider.overrideWithValue(() => fake)],
    );

    container.read(textRecognizerProvider);
    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(fake.closes, 1);
  });
}
