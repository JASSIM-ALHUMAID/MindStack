import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/pdf_import.dart';
import 'package:mindstack/data/pdfrx_pdf_reader.dart';
import 'package:mindstack/domain/card_segmenter.dart';
import 'package:mindstack/domain/pdf_document.dart';
import 'package:pdfrx/pdfrx.dart';

import '../support/fakes.dart';

/// Runs the real PDFium engine on the host, against the sample deck in
/// test/fixtures/pdf.
void main() {
  const samplePath = 'test/fixtures/pdf/mindstack-ocr-sample.pdf';
  late Directory temp;
  late PdfrxPdfReader reader;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mindstack_pdf_test');
    reader = PdfrxPdfReader(
      initialize: pdfrxInitialize,
      tempDirectory: () async => temp,
    );
  });

  tearDown(() => temp.delete(recursive: true));

  Future<OpenPdf> openSample() async {
    final result = await reader.open(samplePath);
    expect(result, isA<PdfOpened>());
    final pdf = (result as PdfOpened).pdf;
    addTearDown(pdf.close);
    return pdf;
  }

  test("reads the sample's text layer page by page", () async {
    final pdf = await openSample();

    expect(pdf.pageCount, 7);
    expect(
      await pdf.pageText(2),
      'Labeled pair\r\nQ: What is the powerhouse of the cell?\r\n'
      'A: The mitochondria',
    );
  });

  test('the sample PDF gives the expected drafts', () async {
    final pdf = await openSample();
    final recognizer = FakeTextRecognizer();
    final importer = PdfImporter(
      recognizer: recognizer,
      segmenter: const CardSegmenter(),
      ids: SequentialIds(),
      logger: RecordingLogger(),
    );

    final read = await importer.readPages(
      pdf,
      onPage: (_) {},
      isCancelled: () => false,
    );
    final drafts = importer.draftsFrom(read.pages);

    expect(read.failedPages, 0);
    expect(recognizer.paths, isEmpty, reason: 'text layer, no OCR');
    expect(drafts.map((d) => (d.sourceRef, d.question, d.answer)), [
      ('Page 2', 'What is the powerhouse of the cell?', 'The mitochondria'),
      (
        'Page 3',
        'What are the three types of memory?',
        'Sensory memory\nWorking memory\nLong-term memory',
      ),
      (
        'Page 4',
        'Which of the following is a programming language?\n'
            'A. HTML\nB. Python\nC. CSS\nD. JSON',
        'B. Python',
      ),
      (
        'Page 5',
        'Which of these is a version control system?\nA. Git\nB. HTML\nC. CSS',
        'A. Git',
      ),
      (
        'Page 6',
        'Which of these is a markup language?\na) HTML\nb) Python',
        'a) HTML',
      ),
      (
        'Page 7',
        'What is working memory?',
        'A small store of information held while doing a task',
      ),
    ]);
  });

  test('draws a page as a PNG within the size limit', () async {
    final pdf = await openSample();

    final image = await pdf.renderPage(2, maxEdge: kPdfRenderMaxEdge);
    final bytes = await File(image.path).readAsBytes();

    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
    final header = ByteData.sublistView(bytes, 16, 24);
    // The sample is 960 x 540 points, so the width is the longer side
    expect(header.getUint32(0), kPdfRenderMaxEdge);
    expect(header.getUint32(4), 1125);

    await image.delete();
    await image.delete();
    expect(await File(image.path).exists(), isFalse);
  });

  test('a damaged file is unreadable', () async {
    final damaged = File('${temp.path}/damaged.pdf')
      ..writeAsStringSync('%PDF-1.7 this is not really a PDF');

    final result = await reader.open(damaged.path);

    expect(
      result,
      isA<PdfOpenFailure>().having(
        (f) => f.kind,
        'kind',
        PdfOpenFailureKind.unreadable,
      ),
    );
  });

  test('a missing file is unreadable', () async {
    final result = await reader.open('${temp.path}/missing.pdf');

    expect(result, isA<PdfOpenFailure>());
  });
}
