import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' as picker;

import '../domain/image_picker.dart';

/// [ImagePicker] backed by the image_picker plugin
final class PlatformImagePicker implements ImagePicker {
  const PlatformImagePicker();

  @override
  Future<ImagePickResult> pickGallery() async {
    try {
      final files = await picker.ImagePicker().pickMultiImage();
      return ImagesPicked([for (final file in files) _PickedImage(file)]);
    } on PlatformException catch (error) {
      return _permissionFailure(error);
    }
  }

  @override
  Future<ImagePickResult> pickCamera() async {
    try {
      final file = await picker.ImagePicker().pickImage(
        source: picker.ImageSource.camera,
      );
      return ImagesPicked(file == null ? const [] : [_PickedImage(file)]);
    } on PlatformException catch (error) {
      return _permissionFailure(error);
    }
  }

  ImagePickResult _permissionFailure(PlatformException error) {
    return switch (error.code) {
      'camera_access_denied' || 'photo_access_denied' => const ImagePickFailure(
        ImagePickFailureKind.denied,
      ),
      _ => throw error,
    };
  }
}

final class _PickedImage implements PickedImage {
  const _PickedImage(this._file);

  final picker.XFile _file;

  @override
  String get path => _file.path;
}
