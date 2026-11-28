/// A PDF the user picked
abstract interface class PickedPdf {
  /// Null when the size cannot be determined
  Future<int?> length();

  /// A path on the device the PDF can be opened from
  Future<String> localPath();
}

/// Opens the system file picker for PDFs
abstract interface class PdfFilePicker {
  /// Null when the user cancels
  Future<PickedPdf?> pick();
}
