import 'dart:typed_data';

/// A file the user picked. Nothing is read until asked, so a file that is too
/// large can be refused first.
abstract interface class PickedDeckFile {
  /// Null when the size cannot be determined.
  Future<int?> length();

  Future<Uint8List> readAsBytes();
}

/// Opens the system file picker.
abstract interface class DeckFilePicker {
  /// Null when the user cancels.
  Future<PickedDeckFile?> pick();
}
