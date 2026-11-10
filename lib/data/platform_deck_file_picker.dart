import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/deck_file_picker.dart';

/// [DeckFilePicker] backed by the file_picker package.
final class PlatformDeckFilePicker implements DeckFilePicker {
  const PlatformDeckFilePicker();

  @override
  Future<PickedDeckFile?> pick() async {
    // Any file type: Android has no MIME type for .mindstack, so filtering by
    // extension is unreliable. The parser checks the contents instead.
    final file = await FilePicker.pickFile();
    return file == null ? null : _PlatformPickedFile(file);
  }
}

final class _PlatformPickedFile implements PickedDeckFile {
  const _PlatformPickedFile(this._file);

  final PlatformFile _file;

  @override
  Future<int?> length() => _file.length();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();
}
