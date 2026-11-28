import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/inbox.dart';
import 'package:mindstack/application/ocr.dart';
import 'package:mindstack/application/pdf_import.dart';
import 'package:mindstack/application/services.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/pdf_document.dart';
import 'package:mindstack/domain/pdf_file_picker.dart';
import 'package:mindstack/domain/text_recognizer.dart';

import '../support/container.dart';
import '../support/fakes.dart';

void main() {
  ({
    ProviderContainer container,
    FakePdfFilePicker picker,
    FakePdfReader reader,
    FakeTextRecognizer recognizer,
    RecordingLogger logger,
  })
  build({
    List<PickedPdf?>? files,
    List<Object> opens = const [],
    List<Object> ocr = const [],
  }) {
    final picker = FakePdfFilePicker(files ?? [FakePickedPdf()]);
    final reader = FakePdfReader(opens);
    final recognizer = FakeTextRecognizer(ocr);
    final logger = RecordingLogger();
    final container = makeContainer(
      overrides: [
        pdfFilePickerProvider.overrideWithValue(picker),
        pdfReaderProvider.overrideWithValue(reader),
        textRecognizerFactoryProvider.overrideWithValue(() => recognizer),
        loggerProvider.overrideWithValue(logger),
      ],
    );
    return (
      container: container,
      picker: picker,
      reader: reader,
      recognizer: recognizer,
      logger: logger,
    );
  }

  PdfImportNotifier notifier(ProviderContainer c) =>
      c.read(pdfImportProvider.notifier);

  String? failure(ProviderContainer c) => switch (c.read(pdfImportProvider)) {
    PdfImportFailed(:final message) => message,
    _ => null,
  };

  group('reading pages', () {
    test('text pages become PDF drafts labelled by page', () async {
      final pdf = FakeOpenPdf([
        'Title slide for the lecture',
        'Q: What is the powerhouse of the cell?\nA: The mitochondria',
        'Question line\nWhat are the three types of memory?\n• Sensory\n• Working',
      ]);
      final h = build(opens: [pdf]);

      final result = await notifier(h.container).pickAndImport();

      expect(
        result,
        isA<PdfImportSucceeded>()
            .having((r) => r.count, 'count', 2)
            .having((r) => r.failedPages, 'failedPages', 0),
      );
      expect(h.reader.paths, ['/tmp/lecture.pdf']);
      expect(h.recognizer.paths, isEmpty);
      expect(pdf.closes, 1);
      expect(h.container.read(pdfImportProvider), isA<PdfImportIdle>());
      final drafts = await h.container.read(draftsProvider.future);
      expect(drafts.map((d) => (d.sourceRef, d.question, d.answer)), [
        ('Page 2', 'What is the powerhouse of the cell?', 'The mitochondria'),
        ('Page 3', 'What are the three types of memory?', 'Sensory\nWorking'),
      ]);
      expect(drafts.every((d) => d.source == CardSource.pdf), isTrue);
    });

    test(
      'a scanned page is drawn, read by OCR and its image deleted',
      () async {
        final pdf = FakeOpenPdf(['', 'Q: What is X on a text page?\nA: Y']);
        final h = build(
          opens: [pdf],
          ocr: const [
            RecognizedText([RecognizedBlock('Q: What is scanned?\nA: Paper')]),
          ],
        );

        await notifier(h.container).pickAndImport();

        expect(pdf.renders, [(page: 1, maxEdge: kPdfRenderMaxEdge)]);
        expect(h.recognizer.paths, ['/tmp/page-1.png']);
        expect(pdf.deleted, ['/tmp/page-1.png']);
        final drafts = await h.container.read(draftsProvider.future);
        expect(drafts.map((d) => d.question), [
          'What is scanned?',
          'What is X on a text page?',
        ]);
      },
    );

    test('a page with only a few letters counts as scanned', () async {
      final pdf = FakeOpenPdf(['Fig. 3']);
      final h = build(
        opens: [pdf],
        ocr: const [
          RecognizedText([RecognizedBlock('Q: What is shown?\nA: A cell')]),
        ],
      );

      await notifier(h.container).pickAndImport();

      expect(pdf.renders.single.page, 1);
    });

    test('a page whose text cannot be read falls back to OCR', () async {
      final pdf = FakeOpenPdf([const FormatException('bad text')]);
      final h = build(
        opens: [pdf],
        ocr: const [
          RecognizedText([RecognizedBlock('Q: What is X?\nA: Y')]),
        ],
      );

      final result = await notifier(h.container).pickAndImport();

      expect(result, isA<PdfImportSucceeded>());
      expect(h.logger.errors.single.message, 'PDF text failed on page 1');
    });

    test('a failed page is skipped and counted; the rest import', () async {
      final pdf = FakeOpenPdf(
        ['', '', 'Q: What is X?\nA: Y'],
        renderFailures: {1},
      );
      final h = build(
        opens: [pdf],
        ocr: const [RecognitionFailure(RecognitionFailureKind.unreadable)],
      );

      final result = await notifier(h.container).pickAndImport();

      expect(
        result,
        isA<PdfImportSucceeded>()
            .having((r) => r.count, 'count', 1)
            .having((r) => r.failedPages, 'failedPages', 2),
      );
      expect(pdf.deleted, ['/tmp/page-2.png']);
    });

    test('a page with no text at all is not a failure', () async {
      final pdf = FakeOpenPdf(['', 'Q: What is X?\nA: Y']);
      final h = build(opens: [pdf]);

      final result = await notifier(h.container).pickAndImport();

      expect(
        result,
        isA<PdfImportSucceeded>().having((r) => r.failedPages, 'failed', 0),
      );
    });

    test('a question and its answer on the next page make one card', () async {
      final pdf = FakeOpenPdf([
        'Quiz time\nQ: What is working memory?',
        'Answer\nA: A small store of information',
      ]);
      final h = build(opens: [pdf]);

      await notifier(h.container).pickAndImport();

      final drafts = await h.container.read(draftsProvider.future);
      expect(drafts.single.sourceRef, 'Pages 1–2');
      expect(drafts.single.answer, 'A small store of information');
    });

    test('reports each page while reading', () async {
      final pdf = FakeOpenPdf.cards(3);
      final h = build(opens: [pdf]);
      final seen = <String>[];
      h.container.listen(pdfImportProvider, (_, next) {
        if (next is PdfImportReading) {
          seen.add('${next.page}/${next.pageCount}');
        }
      });

      await notifier(h.container).pickAndImport();

      expect(seen, ['0/0', '1/3', '2/3', '3/3']);
    });

    test('the largest allowed PDF reads every page', () async {
      final pdf = FakeOpenPdf.cards(kMaxPdfPages);
      final h = build(opens: [pdf]);

      final result = await notifier(h.container).pickAndImport();

      expect(
        result,
        isA<PdfImportSucceeded>().having((r) => r.count, 'count', 100),
      );
      expect(pdf.textReads.length, kMaxPdfPages);
    });
  });

  group('refused files', () {
    test('cancelling the picker opens nothing', () async {
      final h = build(files: const []);

      final result = await notifier(h.container).pickAndImport();

      expect(result, isA<PdfImportCancelled>());
      expect(h.reader.paths, isEmpty);
      expect(h.container.read(pdfImportProvider), isA<PdfImportIdle>());
    });

    test('a file over 50 MB is refused before it is opened', () async {
      final h = build(files: [FakePickedPdf(size: kMaxPdfBytes + 1)]);

      final result = await notifier(h.container).pickAndImport();

      expect(result, isA<PdfImportRefused>());
      expect(failure(h.container), kPdfTooLargeMessage);
      expect(h.reader.paths, isEmpty);
    });

    test('more than 100 pages is refused and the PDF closed', () async {
      final pdf = FakeOpenPdf.cards(kMaxPdfPages + 1);
      final h = build(opens: [pdf]);

      await notifier(h.container).pickAndImport();

      expect(failure(h.container), pdfTooManyPagesMessage(101));
      expect(pdf.textReads, isEmpty);
      expect(pdf.closes, 1);
    });

    test('a password-protected PDF says so', () async {
      final h = build(
        opens: [const PdfOpenFailure(PdfOpenFailureKind.passwordProtected)],
      );

      await notifier(h.container).pickAndImport();

      expect(
        failure(h.container),
        'This PDF is password-protected. Remove the password and try again.',
      );
      expect(
        (h.container.read(pdfImportProvider) as PdfImportFailed).canRetry,
        isFalse,
      );
    });

    test('a damaged PDF says so', () async {
      final h = build(
        opens: [const PdfOpenFailure(PdfOpenFailureKind.unreadable)],
      );

      await notifier(h.container).pickAndImport();

      expect(
        failure(h.container),
        "This PDF couldn't be opened. It may be damaged.",
      );
    });

    test('a PDF without cards says so and adds nothing', () async {
      final h = build(
        opens: [
          FakeOpenPdf(['Just a title slide here']),
        ],
      );

      await notifier(h.container).pickAndImport();

      expect(failure(h.container), kPdfNoCardsMessage);
      expect(await h.container.read(draftsProvider.future), isEmpty);
    });

    test('every page failing explains why', () async {
      final h = build(
        opens: [
          FakeOpenPdf(['', '']),
        ],
        ocr: const [
          RecognitionFailure(RecognitionFailureKind.engineUnavailable),
          RecognitionFailure(RecognitionFailureKind.engineUnavailable),
        ],
      );

      await notifier(h.container).pickAndImport();

      expect(
        failure(h.container),
        'Text recognition is not available on this device.',
      );
    });

    test('an unexpected error can be retried with the same file', () async {
      final h = build(opens: [StateError('boom'), FakeOpenPdf.cards(1)]);

      await notifier(h.container).pickAndImport();
      expect(failure(h.container), kPdfImportFailureMessage);
      expect(
        (h.container.read(pdfImportProvider) as PdfImportFailed).canRetry,
        isTrue,
      );
      expect(h.logger.errors.single.message, 'PDF import failed');

      final result = await notifier(h.container).retry();

      expect(result, isA<PdfImportSucceeded>());
      expect(h.picker.picks, 1);
      expect(h.reader.paths, ['/tmp/lecture.pdf', '/tmp/lecture.pdf']);
    });
  });

  group('cancel', () {
    Future<
      ({
        ProviderContainer container,
        FakeOpenPdf pdf,
        Future<PdfImportResult> result,
      })
    >
    cancelOnPage(int page, {int pages = 3}) async {
      final pdf = FakeOpenPdf.cards(pages)
        ..gate = Completer<void>()
        ..gatedPage = page;
      final h = build(opens: [pdf]);
      final result = notifier(h.container).pickAndImport();
      while (pdf.textReads.length < page) {
        await Future<void>.delayed(Duration.zero);
      }
      notifier(h.container).cancel();
      final state = h.container.read(pdfImportProvider) as PdfImportReading;
      expect(state.cancelling, isTrue);
      pdf.gate!.complete();
      return (container: h.container, pdf: pdf, result: result);
    }

    test('stops after the current page and keeps the drafts', () async {
      final run = await cancelOnPage(2);

      final result = await run.result;

      expect(
        result,
        isA<PdfImportStopped>()
            .having((r) => r.count, 'count', 2)
            .having((r) => r.pagesRead, 'pagesRead', 2)
            .having((r) => r.pageCount, 'pageCount', 3),
      );
      expect(run.pdf.textReads, [1, 2]);
      expect(run.pdf.closes, 1);
      final repository = run.container.read(draftRepositoryProvider);
      expect(await repository.selected(), isEmpty);

      final kept = await notifier(run.container).keepPartial();

      expect(kept, 2);
      final drafts = await repository.selected();
      expect(drafts.map((d) => d.sourceRef), ['Page 1', 'Page 2']);
    });

    test('discarding drops the drafts', () async {
      final run = await cancelOnPage(1);

      expect(await run.result, isA<PdfImportStopped>());
      notifier(run.container).discardPartial();

      expect(await notifier(run.container).keepPartial(), 0);
      expect(await run.container.read(draftsProvider.future), isEmpty);
    });

    test('a cancel before any card is a plain cancel', () async {
      final pdf = FakeOpenPdf(['Title slide only here', 'Q: What is X?\nA: Y'])
        ..gate = Completer<void>();
      final h = build(opens: [pdf]);
      final result = notifier(h.container).pickAndImport();
      while (pdf.textReads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      notifier(h.container).cancel();
      pdf.gate!.complete();

      expect(await result, isA<PdfImportCancelled>());
      expect(h.container.read(pdfImportProvider), isA<PdfImportIdle>());
    });

    test('a second import while reading is ignored', () async {
      final pdf = FakeOpenPdf.cards(1)..gate = Completer<void>();
      final h = build(opens: [pdf]);
      final first = notifier(h.container).pickAndImport();
      await Future<void>.delayed(Duration.zero);

      expect(
        await notifier(h.container).pickAndImport(),
        isA<PdfImportCancelled>(),
      );
      pdf.gate!.complete();
      expect(await first, isA<PdfImportSucceeded>());
      expect(h.picker.picks, 1);
    });
  });
}
