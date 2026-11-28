import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ids.dart';
import '../core/logger.dart';
import '../domain/card_segmenter.dart';
import '../domain/enums.dart';
import '../domain/models/draft_card.dart';
import '../domain/pdf_document.dart';
import '../domain/pdf_file_picker.dart';
import '../domain/pdf_pages.dart';
import '../domain/text_recognizer.dart';
import 'core_providers.dart';
import 'inbox.dart';
import 'ocr.dart';
import 'services.dart';

const int kMaxPdfPages = 100;
const int kMaxPdfBytes = 50 * 1024 * 1024;

/// Longer side of a scanned page drawn for OCR, in pixels
const int kPdfRenderMaxEdge = 2000;

/// A page whose text layer has fewer letters than this is treated as scanned
const int kMinTextLayerLetters = 10;

const String kPdfImportFailureMessage =
    "Couldn't import this PDF. Please try again.";
const String kPdfNoCardsMessage = 'No cards were found in this PDF.';
const String kPdfTooLargeMessage =
    'This PDF is over 50 MB. Choose a smaller file.';
const String kPdfPagesUnreadableMessage = "This PDF's pages couldn't be read.";

String pdfTooManyPagesMessage(int pageCount) =>
    'This PDF has $pageCount pages. MindStack reads up to $kMaxPdfPages '
    'pages at a time.';

final pdfImporterProvider = Provider<PdfImporter>(
  (ref) => PdfImporter(
    recognizer: ref.watch(textRecognizerProvider),
    segmenter: ref.watch(cardSegmenterProvider),
    ids: ref.watch(idGeneratorProvider),
    logger: ref.watch(loggerProvider),
  ),
);

final pdfImportProvider = NotifierProvider<PdfImportNotifier, PdfImportState>(
  PdfImportNotifier.new,
);

/// What came out of reading a PDF's pages
final class PdfPagesRead {
  const PdfPagesRead({
    required this.pages,
    required this.pagesRead,
    required this.failedPages,
    required this.cancelled,
    this.lastFailure,
  });

  /// Pages that had text, in order
  final List<PdfPageText> pages;

  /// Pages tried before the end or a cancel
  final int pagesRead;

  /// Pages that could not be drawn or recognised
  final int failedPages;

  final bool cancelled;

  /// The last OCR failure, to explain why every page failed
  final RecognitionFailure? lastFailure;
}

/// Reads PDF pages one at a time and turns them into drafts.
///
/// A page's own text is used when it has some; a scanned page is drawn and
/// read by OCR, and its image is deleted straight after. Only one page image
/// exists at a time, which bounds memory on long PDFs.
final class PdfImporter {
  const PdfImporter({
    required this._recognizer,
    required this._segmenter,
    required this._ids,
    required this._logger,
  });

  final TextRecognizer _recognizer;
  final CardSegmenter _segmenter;
  final IdGenerator _ids;
  final AppLogger _logger;

  static final _letter = RegExp(r'\p{L}', unicode: true);

  /// Calls [onPage] before each page and stops before the next page once
  /// [isCancelled] returns true. A failed page is counted and skipped.
  Future<PdfPagesRead> readPages(
    OpenPdf pdf, {
    required void Function(int page) onPage,
    required bool Function() isCancelled,
  }) async {
    final pages = <PdfPageText>[];
    var failed = 0;
    var read = 0;
    RecognitionFailure? lastFailure;
    for (var page = 1; page <= pdf.pageCount; page++) {
      if (isCancelled()) {
        return PdfPagesRead(
          pages: pages,
          pagesRead: read,
          failedPages: failed,
          cancelled: true,
          lastFailure: lastFailure,
        );
      }
      onPage(page);
      read++;
      final text = await _textLayer(pdf, page);
      if (text != null) {
        pages.add(PdfPageText(page, [RecognizedBlock(text)]));
        continue;
      }
      final recognized = await _recognize(pdf, page);
      switch (recognized) {
        case RecognizedText(:final blocks):
          pages.add(PdfPageText(page, blocks));
        case RecognitionFailure(kind: RecognitionFailureKind.noText):
          break;
        case final RecognitionFailure failure:
          failed++;
          lastFailure = failure;
      }
    }
    return PdfPagesRead(
      pages: pages,
      pagesRead: read,
      failedPages: failed,
      cancelled: false,
      lastFailure: lastFailure,
    );
  }

  List<DraftCard> draftsFrom(List<PdfPageText> pages) => [
    for (final unit in PdfPagePreparer(_segmenter).prepare(pages))
      for (final segment in _segmenter.segment(unit.blocks))
        DraftCard(
          id: _ids.newId(),
          source: CardSource.pdf,
          sourceRef: unit.label,
          question: segment.question,
          answer: segment.answer,
        ),
  ];

  /// Null when the page has too little text of its own, so it needs OCR
  Future<String?> _textLayer(OpenPdf pdf, int page) async {
    try {
      final text = await pdf.pageText(page);
      return _letter.allMatches(text).length >= kMinTextLayerLetters
          ? text
          : null;
    } on Object catch (error, stack) {
      _logger.error('PDF text failed on page $page', error, stack);
      return null;
    }
  }

  Future<RecognitionResult> _recognize(OpenPdf pdf, int page) async {
    RenderedPage? image;
    try {
      image = await pdf.renderPage(page, maxEdge: kPdfRenderMaxEdge);
      return await _recognizer.recognizeText(image.path);
    } on Object catch (error, stack) {
      _logger.error('PDF OCR failed on page $page', error, stack);
      return const RecognitionFailure(RecognitionFailureKind.unreadable);
    } finally {
      await image?.delete();
    }
  }
}

sealed class PdfImportState {
  const PdfImportState();
}

final class PdfImportIdle extends PdfImportState {
  const PdfImportIdle();
}

/// [page] is 0 while the file is being opened
final class PdfImportReading extends PdfImportState {
  const PdfImportReading({
    this.page = 0,
    this.pageCount = 0,
    this.cancelling = false,
  });

  final int page;
  final int pageCount;

  /// Cancel was tapped; the current page finishes first
  final bool cancelling;
}

final class PdfImportFailed extends PdfImportState {
  const PdfImportFailed(this.message, {this.canRetry = false});

  /// Safe to show to the user
  final String message;

  /// False when the same file would fail again
  final bool canRetry;
}

sealed class PdfImportResult {
  const PdfImportResult();
}

final class PdfImportSucceeded extends PdfImportResult {
  const PdfImportSucceeded(this.count, {required this.failedPages});

  final int count;

  final int failedPages;
}

/// Cancelled after some drafts were found. Call
/// [PdfImportNotifier.keepPartial] or [PdfImportNotifier.discardPartial].
final class PdfImportStopped extends PdfImportResult {
  const PdfImportStopped(
    this.count, {
    required this.pagesRead,
    required this.pageCount,
  });

  final int count;
  final int pagesRead;
  final int pageCount;
}

final class PdfImportCancelled extends PdfImportResult {
  const PdfImportCancelled();
}

/// Nothing was imported; [PdfImportNotifier.state] says why
final class PdfImportRefused extends PdfImportResult {
  const PdfImportRefused();
}

/// Picks a PDF, reads it page by page and adds the drafts to the Inbox
final class PdfImportNotifier extends Notifier<PdfImportState> {
  PickedPdf? _lastFile;
  bool _cancelRequested = false;
  List<DraftCard> _pending = const [];

  @override
  PdfImportState build() => const PdfImportIdle();

  Future<PdfImportResult> pickAndImport() async {
    if (state is PdfImportReading) return const PdfImportCancelled();
    final PickedPdf? file;
    try {
      file = await ref.read(pdfFilePickerProvider).pick();
    } on Object catch (error, stack) {
      ref.read(loggerProvider).error('PDF picker failed', error, stack);
      return _fail(kPdfImportFailureMessage);
    }
    if (file == null) {
      state = const PdfImportIdle();
      return const PdfImportCancelled();
    }
    _lastFile = file;
    return _import(file);
  }

  /// Reads the last picked file again
  Future<PdfImportResult> retry() {
    final file = _lastFile;
    if (file == null || state is PdfImportReading) return pickAndImport();
    return _import(file);
  }

  /// Stops after the page being read
  void cancel() {
    final current = state;
    if (current is! PdfImportReading || current.cancelling) return;
    _cancelRequested = true;
    state = PdfImportReading(
      page: current.page,
      pageCount: current.pageCount,
      cancelling: true,
    );
  }

  /// Adds the drafts found before a cancel and returns how many
  Future<int> keepPartial() async {
    final drafts = _pending;
    _pending = const [];
    if (drafts.isNotEmpty) {
      await ref.read(inboxCommandsProvider).addDrafts(drafts);
    }
    return drafts.length;
  }

  void discardPartial() => _pending = const [];

  Future<PdfImportResult> _import(PickedPdf file) async {
    _cancelRequested = false;
    _pending = const [];
    state = const PdfImportReading();
    final logger = ref.read(loggerProvider);
    OpenPdf? pdf;
    try {
      final size = await file.length();
      if (size != null && size > kMaxPdfBytes) {
        return _fail(kPdfTooLargeMessage);
      }
      final result = await ref
          .read(pdfReaderProvider)
          .open(await file.localPath());
      final OpenPdf document;
      switch (result) {
        case final PdfOpenFailure failure:
          logger.info('PDF not opened: ${failure.kind.name}');
          return _fail(failure.userMessage);
        case PdfOpened(pdf: final opened):
          document = opened;
      }
      pdf = document;
      final pageCount = document.pageCount;
      if (pageCount > kMaxPdfPages) {
        return _fail(pdfTooManyPagesMessage(pageCount));
      }

      final importer = ref.read(pdfImporterProvider);
      final read = await importer.readPages(
        document,
        onPage: (page) => state = PdfImportReading(
          page: page,
          pageCount: pageCount,
          cancelling: _cancelRequested,
        ),
        isCancelled: () => _cancelRequested,
      );
      final drafts = importer.draftsFrom(read.pages);
      logger.info(
        'PDF: $pageCount pages, ${read.pagesRead} read, '
        '${read.failedPages} failed, ${drafts.length} drafts',
      );

      if (read.cancelled) {
        state = const PdfImportIdle();
        if (drafts.isEmpty) return const PdfImportCancelled();
        _pending = drafts;
        return PdfImportStopped(
          drafts.length,
          pagesRead: read.pagesRead,
          pageCount: pageCount,
        );
      }
      if (drafts.isEmpty) {
        final allFailed = pageCount > 0 && read.failedPages == pageCount;
        final engineMissing =
            read.lastFailure?.kind == RecognitionFailureKind.engineUnavailable;
        return _fail(
          !allFailed
              ? kPdfNoCardsMessage
              : engineMissing
              ? read.lastFailure!.userMessage
              : kPdfPagesUnreadableMessage,
        );
      }
      await ref.read(inboxCommandsProvider).addDrafts(drafts);
      state = const PdfImportIdle();
      return PdfImportSucceeded(drafts.length, failedPages: read.failedPages);
    } on Object catch (error, stack) {
      logger.error('PDF import failed', error, stack);
      return _fail(kPdfImportFailureMessage, canRetry: true);
    } finally {
      _cancelRequested = false;
      await _close(pdf, logger);
    }
  }

  PdfImportResult _fail(String message, {bool canRetry = false}) {
    state = PdfImportFailed(message, canRetry: canRetry);
    return const PdfImportRefused();
  }

  Future<void> _close(OpenPdf? pdf, AppLogger logger) async {
    try {
      await pdf?.close();
    } on Object catch (error, stack) {
      logger.error('PDF close failed', error, stack);
    }
  }
}
