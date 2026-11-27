import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/image_picker.dart';

void main() {
  test('picked images are exposed in order and cannot be mutated', () {
    final images = [
      const FakePickedImage('a.png'),
      const FakePickedImage('b.png'),
    ];
    final result = ImagesPicked(images);

    expect(result.images, images);
    expect(
      () => result.images.add(const FakePickedImage('c.png')),
      throwsUnsupportedError,
    );
  });

  test('an empty pick means the user cancelled', () {
    expect(ImagesPicked(const []).images, isEmpty);
  });

  test('permission failures carry plain-language messages', () {
    expect(
      const ImagePickFailure(ImagePickFailureKind.denied).userMessage,
      'Photo access was denied. Allow photos to import images.',
    );
    expect(
      const ImagePickFailure(ImagePickFailureKind.permanentlyDenied)
          .userMessage,
      'Photo access is turned off. Open settings to allow it.',
    );
  });
}

final class FakePickedImage implements PickedImage {
  const FakePickedImage(this.path);

  @override
  final String path;
}
