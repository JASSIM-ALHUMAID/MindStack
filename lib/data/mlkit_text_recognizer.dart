import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import '../domain/text_recognizer.dart';

/// [TextRecognizer] backed by Google ML Kit on the device.
///
/// The Latin model reads English and other Latin-script text. ML Kit text
/// recognition has no Arabic model, so Arabic screenshots are out of scope.
/// Android is the primary target; device verification comes with the Inbox
/// import. iOS needs ML Kit's Latin OCR resources bundle added before OCR
/// works there.
final class MlKitTextRecognizer implements TextRecognizer {
  mlkit.TextRecognizer? _engine;

  @override
  Future<RecognitionResult> recognizeText(String imagePath) async {
    try {
      if (!await File(imagePath).exists()) {
        return const RecognitionFailure(RecognitionFailureKind.unreadable);
      }
      final engine = _engine ??= mlkit.TextRecognizer(
        script: mlkit.TextRecognitionScript.latin,
      );
      final recognized = await engine.processImage(
        mlkit.InputImage.fromFilePath(imagePath),
      );
      final blocks = [
        for (final block in recognized.blocks)
          if (block.text.trim().isNotEmpty) RecognizedBlock(block.text),
      ];
      if (blocks.isEmpty) {
        return const RecognitionFailure(RecognitionFailureKind.noText);
      }
      return RecognizedText(blocks);
    } on PlatformException catch (error) {
      return RecognitionFailure(_mapPlatformError(error));
    } on MissingPluginException {
      return const RecognitionFailure(RecognitionFailureKind.engineUnavailable);
    } on FileSystemException {
      return const RecognitionFailure(RecognitionFailureKind.unreadable);
    }
  }

  @override
  Future<void> close() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try {
      await engine.close();
    } on PlatformException {
      // The native engine is already gone; there is nothing to release
      return;
    } on MissingPluginException {
      // Tests and unsupported platforms have no native engine
      return;
    }
  }

  RecognitionFailureKind _mapPlatformError(PlatformException error) {
    return error.code == 'InputImageConverterError'
        ? RecognitionFailureKind.unreadable
        : RecognitionFailureKind.engineUnavailable;
  }
}
