import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/image_import.dart';
import 'package:mindstack/application/inbox.dart';
import 'package:mindstack/application/ocr.dart';
import 'package:mindstack/application/services.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/image_picker.dart';
import 'package:mindstack/domain/text_recognizer.dart';

import '../support/container.dart';
import '../support/fakes.dart';

void main() {
  const twoCards = RecognizedText([
    RecognizedBlock('Q: What is X?\nA: Y'),
    RecognizedBlock('Q: What is Z?\nA: W'),
  ]);
  const oneCard = RecognizedText([RecognizedBlock('Q: What is P?\nA: Q')]);
  const noText = RecognitionFailure(RecognitionFailureKind.noText);

  ProviderContainer build({
    FakeImagePicker? picker,
    FakeAppSettings? settings,
    FakeTextRecognizer? recognizer,
    RecordingLogger? logger,
  }) {
    final recorder = logger ?? RecordingLogger();
    return makeContainer(
      overrides: [
        imagePickerProvider.overrideWithValue(picker ?? FakeImagePicker()),
        appSettingsProvider.overrideWithValue(settings ?? FakeAppSettings()),
        if (recognizer != null)
          textRecognizerFactoryProvider.overrideWithValue(() => recognizer),
        loggerProvider.overrideWithValue(recorder),
      ],
    );
  }

  group('successful imports', () {
    test('gallery multi-select inserts one tagged batch per image', () async {
      final picker = FakeImagePicker([
        ImagesPicked([
          const FakePickedImage('/tmp/s1.png'),
          const FakePickedImage('/tmp/s2.png'),
        ]),
      ]);
      final recognizer = FakeTextRecognizer([twoCards, oneCard]);
      final container = build(picker: picker, recognizer: recognizer);

      final result = await container
          .read(imageImportProvider.notifier)
          .import(ImageImportKind.gallery);

      expect(
        result,
        isA<ImageImportSucceeded>().having((r) => r.count, 'count', 3),
      );
      expect(picker.galleryCalls, 1);
      expect(picker.cameraCalls, 0);
      expect(recognizer.paths, ['/tmp/s1.png', '/tmp/s2.png']);
      expect(container.read(imageImportProvider), isA<ImageImportIdle>());
      expect(container.read(ocrProgressProvider), isNull);
      final drafts = await container.read(draftsProvider.future);
      expect(drafts.map((d) => d.sourceRef), [
        'Screenshot 1',
        'Screenshot 1',
        'Screenshot 2',
      ]);
      expect(drafts.every((d) => d.source == CardSource.slide), isTrue);
      expect(drafts.every((d) => d.selected), isTrue);
    });

    test('camera import tags drafts as photos', () async {
      final picker = FakeImagePicker([
        ImagesPicked([const FakePickedImage('/tmp/photo.png')]),
      ]);
      final container = build(
        picker: picker,
        recognizer: FakeTextRecognizer([oneCard]),
      );

      await container
          .read(imageImportProvider.notifier)
          .import(ImageImportKind.camera);

      expect(picker.cameraCalls, 1);
      expect(picker.galleryCalls, 0);
      final drafts = await container.read(draftsProvider.future);
      expect(drafts.single.source, CardSource.photo);
      expect(drafts.single.sourceRef, 'Photo 1');
    });

    test('a readable image is kept when another image has no text', () async {
      final container = build(
        picker: FakeImagePicker([
          ImagesPicked([
            const FakePickedImage('/tmp/a.png'),
            const FakePickedImage('/tmp/b.png'),
          ]),
        ]),
        recognizer: FakeTextRecognizer([oneCard, noText]),
      );

      final result = await container
          .read(imageImportProvider.notifier)
          .import(ImageImportKind.gallery);

      expect(
        result,
        isA<ImageImportSucceeded>().having((r) => r.skipped, 'skipped', 1),
      );
      final drafts = await container.read(draftsProvider.future);
      expect(drafts, hasLength(1));
      expect(drafts.single.sourceRef, 'Screenshot 1');
    });
  });

  group('cancellation and failure', () {
    test(
      'cancelling the picker inserts nothing and reports no error',
      () async {
        final container = build(
          picker: FakeImagePicker([ImagesPicked(const [])]),
          recognizer: FakeTextRecognizer([oneCard]),
        );

        final result = await container
            .read(imageImportProvider.notifier)
            .import(ImageImportKind.gallery);

        expect(result, isA<ImageImportCancelled>());
        expect(container.read(imageImportProvider), isA<ImageImportIdle>());
        expect(await container.read(draftsProvider.future), isEmpty);
      },
    );

    test(
      'a denied pick shows a plain-language message and offers retry',
      () async {
        final container = build(
          picker: FakeImagePicker([
            const ImagePickFailure(ImagePickFailureKind.denied),
          ]),
        );

        final result = await container
            .read(imageImportProvider.notifier)
            .import(ImageImportKind.camera);

        expect(result, isA<ImageImportRefused>());
        final state = container.read(imageImportProvider);
        expect(state, isA<ImageImportFailed>());
        final failure = state as ImageImportFailed;
        expect(
          failure.message,
          'Photo access was denied. Allow photos to import images.',
        );
        expect(failure.canRetry, isTrue);
        expect(failure.canOpenSettings, isFalse);
        expect(await container.read(draftsProvider.future), isEmpty);
      },
    );

    test('a second denial offers open settings', () async {
      final picker = FakeImagePicker([
        const ImagePickFailure(ImagePickFailureKind.denied),
        const ImagePickFailure(ImagePickFailureKind.denied),
      ]);
      final container = build(picker: picker);
      final commands = container.read(imageImportProvider.notifier);

      await commands.import(ImageImportKind.camera);
      await commands.import(ImageImportKind.camera);

      final failure = container.read(imageImportProvider) as ImageImportFailed;
      expect(failure.canOpenSettings, isTrue);
      expect(failure.canRetry, isFalse);
    });

    test('an already-permanent denial offers open settings at once', () async {
      final container = build(
        picker: FakeImagePicker([
          const ImagePickFailure(ImagePickFailureKind.permanentlyDenied),
        ]),
      );

      await container
          .read(imageImportProvider.notifier)
          .import(ImageImportKind.gallery);

      final failure = container.read(imageImportProvider) as ImageImportFailed;
      expect(failure.canOpenSettings, isTrue);
      expect(
        failure.message,
        'Photo access is turned off. Open settings to allow it.',
      );
    });

    test('no text in the image reports the recogniser message', () async {
      final container = build(
        picker: FakeImagePicker([
          ImagesPicked([const FakePickedImage('/tmp/blank.png')]),
        ]),
        recognizer: FakeTextRecognizer([noText]),
      );

      final result = await container
          .read(imageImportProvider.notifier)
          .import(ImageImportKind.camera);

      expect(result, isA<ImageImportRefused>());
      final failure = container.read(imageImportProvider) as ImageImportFailed;
      expect(failure.message, 'No text was found in this image.');
      expect(await container.read(draftsProvider.future), isEmpty);
      expect(container.read(ocrProgressProvider), isNull);
    });

    test('a picker exception is logged and reported generically', () async {
      final logger = RecordingLogger();
      final container = build(
        picker: FakeImagePicker()..queueError(StateError('boom')),
        logger: logger,
      );

      await container
          .read(imageImportProvider.notifier)
          .import(ImageImportKind.gallery);

      final failure = container.read(imageImportProvider) as ImageImportFailed;
      expect(failure.message, kImageImportFailureMessage);
      expect(logger.errors, hasLength(1));
      expect(logger.errors.single.error, isA<StateError>());
    });

    test('an unreadable second image keeps the first batch', () async {
      final container = build(
        picker: FakeImagePicker([
          ImagesPicked([
            const FakePickedImage('/tmp/a.png'),
            const FakePickedImage('/tmp/b.png'),
          ]),
        ]),
        recognizer: FakeTextRecognizer([oneCard])
          ..queueError(StateError('decode failed')),
      );

      final result = await container
          .read(imageImportProvider.notifier)
          .import(ImageImportKind.gallery);

      expect(
        result,
        isA<ImageImportSucceeded>().having((r) => r.count, 'count', 1),
      );
      final drafts = await container.read(draftsProvider.future);
      expect(drafts, hasLength(1));
      expect(drafts.single.sourceRef, 'Screenshot 1');
      expect(container.read(ocrProgressProvider), isNull);
    });

    test('a second import is refused while one is running', () async {
      final gate = Completer<void>();
      final picker = FakeImagePicker([
        ImagesPicked([const FakePickedImage('/tmp/a.png')]),
        ImagesPicked([const FakePickedImage('/tmp/b.png')]),
      ]);
      final container = build(
        picker: picker,
        recognizer: FakeTextRecognizer([oneCard, oneCard])..gate = gate,
      );
      final commands = container.read(imageImportProvider.notifier);

      final first = commands.import(ImageImportKind.gallery);
      final second = await commands.import(ImageImportKind.gallery);

      expect(second, isA<ImageImportCancelled>());
      expect(picker.galleryCalls, 1);
      gate.complete();
      await first;
    });
  });

  test('open settings returns whether the platform opened the page', () async {
    final settings = FakeAppSettings(result: false);
    final container = build(settings: settings);

    final opened = await container
        .read(imageImportProvider.notifier)
        .openSettings();

    expect(opened, isFalse);
    expect(settings.opens, 1);
  });
}
