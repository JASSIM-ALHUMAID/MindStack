/// An image the user picked, stored at [path] on the device
abstract interface class PickedImage {
  String get path;
}

enum ImagePickFailureKind { denied, permanentlyDenied }

sealed class ImagePickResult {
  const ImagePickResult();
}

/// [images] is empty when the user cancelled
final class ImagesPicked extends ImagePickResult {
  ImagesPicked(List<PickedImage> images) : images = List.unmodifiable(images);

  final List<PickedImage> images;
}

final class ImagePickFailure extends ImagePickResult {
  const ImagePickFailure(this.kind);

  final ImagePickFailureKind kind;

  /// Safe to show to the user
  String get userMessage => switch (kind) {
    ImagePickFailureKind.denied =>
      'Photo access was denied. Allow photos to import images.',
    ImagePickFailureKind.permanentlyDenied =>
      'Photo access is turned off. Open settings to allow it.',
  };
}

/// Opens the gallery or camera and returns images as local file paths
abstract interface class ImagePicker {
  /// Multiple screenshots may be picked; an empty [ImagesPicked] is a cancel
  Future<ImagePickResult> pickGallery();

  Future<ImagePickResult> pickCamera();
}
