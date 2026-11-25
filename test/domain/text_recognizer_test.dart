import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/text_recognizer.dart';

void main() {
  test('RecognizedText carries blocks in order', () {
    const blocks = [RecognizedBlock('one'), RecognizedBlock('two')];
    const result = RecognizedText(blocks);
    expect(result.blocks, blocks);
  });

  test('failure messages are plain language', () {
    expect(
      const RecognitionFailure(RecognitionFailureKind.noText).userMessage,
      'No text was found in this image.',
    );
    expect(
      const RecognitionFailure(RecognitionFailureKind.unreadable).userMessage,
      "This image couldn't be opened. Try another one.",
    );
    expect(
      const RecognitionFailure(
        RecognitionFailureKind.engineUnavailable,
      ).userMessage,
      'Text recognition is not available on this device.',
    );
  });
}
