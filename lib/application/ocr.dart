import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../data/mlkit_text_recognizer.dart';
import '../domain/card_segmenter.dart';
import '../domain/enums.dart';
import '../domain/models/draft_card.dart';
import '../domain/text_recognizer.dart';
import 'services.dart';

/// Creates the on-device OCR engine. Override in tests or on unsupported
/// platforms.
final textRecognizerFactoryProvider = Provider<TextRecognizer Function()>(
  (ref) => MlKitTextRecognizer.new,
);

/// The shared on-device OCR engine, closed when the provider is disposed
final textRecognizerProvider = Provider<TextRecognizer>((ref) {
  final recognizer = ref.watch(textRecognizerFactoryProvider)();
  ref.onDispose(() => unawaited(recognizer.close()));
  return recognizer;
});

final cardSegmenterProvider = Provider<CardSegmenter>(
  (ref) => const CardSegmenter(),
);

final ocrImporterProvider = Provider<OcrImporter>(
  (ref) => OcrImporter(
    recognizer: ref.watch(textRecognizerProvider),
    segmenter: ref.watch(cardSegmenterProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// The outcome of scanning one image
sealed class OcrScanResult {
  const OcrScanResult();
}

/// The scan produced [drafts], possibly none
final class OcrScanSuccess extends OcrScanResult {
  OcrScanSuccess({required List<DraftCard> drafts, required this.scannedAt})
    : drafts = List.unmodifiable(drafts);

  /// Drafts in reading order
  final List<DraftCard> drafts;

  /// When the scan finished, from the injected clock
  final DateTime scannedAt;
}

/// The scan could not read the image
final class OcrScanFailure extends OcrScanResult {
  const OcrScanFailure(this.failure);

  final RecognitionFailure failure;

  RecognitionFailureKind get kind => failure.kind;

  /// Plain-language text that is safe to show to the user
  String get userMessage => failure.userMessage;
}

/// Recognises one image and turns it into unsaved drafts
final class OcrImporter {
  const OcrImporter({
    required this._recognizer,
    required this._segmenter,
    required this._ids,
    required this._clock,
    required this._logger,
  });

  final TextRecognizer _recognizer;
  final CardSegmenter _segmenter;
  final IdGenerator _ids;
  final Clock _clock;
  final AppLogger _logger;

  /// Reads [imagePath] and returns drafts tagged with [source] and
  /// [sourceRef], or a typed failure.
  Future<OcrScanResult> scan({
    required String imagePath,
    required CardSource source,
    required String sourceRef,
  }) async {
    final startedAt = _clock.now();
    final RecognitionResult recognized;
    try {
      recognized = await _recognizer.recognizeText(imagePath);
    } on Object catch (error, stack) {
      _logger.error('OCR failed for $imagePath', error, stack);
      return const OcrScanFailure(
        RecognitionFailure(RecognitionFailureKind.engineUnavailable),
      );
    }

    switch (recognized) {
      case final RecognitionFailure failure:
        _logFailure(failure, imagePath);
        return OcrScanFailure(failure);
      case final RecognizedText text:
        final segments = _segmenter.segment(text.blocks);
        final drafts = [
          for (final segment in segments)
            DraftCard(
              id: _ids.newId(),
              source: source,
              sourceRef: sourceRef,
              question: segment.question,
              answer: segment.answer,
            ),
        ];
        final scannedAt = _clock.now();
        _logger.info(
          'OCR $sourceRef: ${text.blocks.length} blocks, '
          '${drafts.length} drafts, '
          '${scannedAt.difference(startedAt).inMilliseconds} ms',
        );
        return OcrScanSuccess(drafts: drafts, scannedAt: scannedAt);
    }
  }

  void _logFailure(RecognitionFailure failure, String imagePath) {
    final message = 'OCR ${failure.kind.name} for $imagePath';
    if (failure.kind == RecognitionFailureKind.engineUnavailable) {
      _logger.error(message, failure, StackTrace.current);
    } else {
      _logger.info(message);
    }
  }
}
