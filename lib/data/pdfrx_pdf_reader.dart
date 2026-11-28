import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../domain/pdf_document.dart';

/// [PdfReader] backed by pdfrx, which runs PDFium on the device.
///
/// [initialize] and [tempDirectory] default to the Flutter app setup; tests
/// pass the plain Dart versions because they have no platform channels.
final class PdfrxPdfReader implements PdfReader {
  PdfrxPdfReader({
    Future<void> Function()? initialize,
    Future<Directory> Function()? tempDirectory,
  }) : _initialize = initialize ?? pdfrxFlutterInitialize,
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final Future<void> Function() _initialize;
  final Future<Directory> Function() _tempDirectory;

  @override
  Future<PdfOpenResult> open(String path) async {
    await _initialize();
    try {
      final document = await PdfDocument.openFile(path);
      return PdfOpened(_PdfrxOpenPdf(document, _tempDirectory));
    } on PdfPasswordException {
      return const PdfOpenFailure(PdfOpenFailureKind.passwordProtected);
    } on PdfException {
      return const PdfOpenFailure(PdfOpenFailureKind.unreadable);
    } on FileSystemException {
      return const PdfOpenFailure(PdfOpenFailureKind.unreadable);
    }
  }
}

final class _PdfrxOpenPdf implements OpenPdf {
  _PdfrxOpenPdf(this._document, this._tempDirectory);

  final PdfDocument _document;
  final Future<Directory> Function() _tempDirectory;

  /// Enough for OCR; more only costs memory
  static const _maxScale = 300 / 72;

  @override
  int get pageCount => _document.pages.length;

  @override
  Future<String> pageText(int pageNumber) async {
    final text = await _document.pages[pageNumber - 1].loadText();
    return text?.fullText ?? '';
  }

  @override
  Future<RenderedPage> renderPage(
    int pageNumber, {
    required int maxEdge,
  }) async {
    final page = _document.pages[pageNumber - 1];
    final scale = min(maxEdge / max(page.width, page.height), _maxScale);
    final width = (page.width * scale).round();
    final height = (page.height * scale).round();
    final pixels = await page.render(
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      backgroundColor: 0xffffffff,
    );
    if (pixels == null) {
      throw PdfException('Page $pageNumber could not be drawn');
    }
    final ui.Image image;
    try {
      image = await pixels.createImage();
    } finally {
      pixels.dispose();
    }
    final ByteData? png;
    try {
      png = await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
    if (png == null) {
      throw PdfException('Page $pageNumber could not be encoded');
    }
    final directory = await _tempDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'mindstack_pdf_page_$pageNumber.png',
    );
    await file.writeAsBytes(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      flush: true,
    );
    return _TempImage(file);
  }

  @override
  Future<void> close() => _document.dispose();
}

final class _TempImage implements RenderedPage {
  _TempImage(this._file);

  final File _file;

  @override
  String get path => _file.path;

  @override
  Future<void> delete() async {
    try {
      if (await _file.exists()) await _file.delete();
    } on FileSystemException {
      // The OS clears the cache folder eventually
      return;
    }
  }
}
