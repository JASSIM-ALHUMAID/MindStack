/// Why a PDF could not be opened
enum PdfOpenFailureKind { passwordProtected, unreadable }

sealed class PdfOpenResult {
  const PdfOpenResult();
}

final class PdfOpened extends PdfOpenResult {
  const PdfOpened(this.pdf);

  final OpenPdf pdf;
}

final class PdfOpenFailure extends PdfOpenResult {
  const PdfOpenFailure(this.kind);

  final PdfOpenFailureKind kind;

  /// Safe to show to the user
  String get userMessage => switch (kind) {
    PdfOpenFailureKind.passwordProtected =>
      'This PDF is password-protected. Remove the password and try again.',
    PdfOpenFailureKind.unreadable =>
      "This PDF couldn't be opened. It may be damaged.",
  };

  @override
  String toString() => 'PdfOpenFailure(${kind.name})';
}

/// A page drawn into a temporary image file
abstract interface class RenderedPage {
  String get path;

  /// Removes the image file; safe to call more than once
  Future<void> delete();
}

/// An open PDF. Pages are numbered from 1; close it when done.
abstract interface class OpenPdf {
  int get pageCount;

  /// The text stored in the page, or an empty string for a scanned page
  Future<String> pageText(int pageNumber);

  /// Draws the page at most [maxEdge] pixels on its longer side
  Future<RenderedPage> renderPage(int pageNumber, {required int maxEdge});

  Future<void> close();
}

/// Opens PDF files on the device
///
/// Expected failures are returned as [PdfOpenFailure]; unexpected errors may
/// propagate and the caller must log and map them.
abstract interface class PdfReader {
  Future<PdfOpenResult> open(String path);
}
