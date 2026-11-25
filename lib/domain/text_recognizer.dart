/// One block of text found in an image, in reading order
class RecognizedBlock {
  const RecognizedBlock(this.text);

  /// Text in the block; lines are separated by newlines
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RecognizedBlock && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'RecognizedBlock($text)';
}

/// Why text recognition did not produce any text
enum RecognitionFailureKind {
  noText,
  unreadable,
  engineUnavailable,
}

/// The outcome of reading one image
sealed class RecognitionResult {
  const RecognitionResult();
}

/// Text found in an image
final class RecognizedText extends RecognitionResult {
  const RecognizedText(this.blocks);

  /// Blocks in the order the engine returned them
  final List<RecognizedBlock> blocks;

  @override
  String toString() => 'RecognizedText(blocks: $blocks)';
}

/// The image could not be turned into text
final class RecognitionFailure extends RecognitionResult {
  const RecognitionFailure(this.kind);

  final RecognitionFailureKind kind;

  /// Plain-language text that is safe to show to the user
  String get userMessage => switch (kind) {
    RecognitionFailureKind.noText => 'No text was found in this image.',
    RecognitionFailureKind.unreadable =>
      "This image couldn't be opened. Try another one.",
    RecognitionFailureKind.engineUnavailable =>
      'Text recognition is not available on this device.',
  };

  @override
  String toString() => 'RecognitionFailure(${kind.name})';
}

/// Reads text from an image on the device
///
/// Expected failures are returned as [RecognitionFailure]; unexpected errors
/// may propagate and the caller must log and map them.
abstract interface class TextRecognizer {
  /// Reads the local image file at [imagePath]
  Future<RecognitionResult> recognizeText(String imagePath);

  /// Releases the native engine; safe to call more than once
  Future<void> close();
}
