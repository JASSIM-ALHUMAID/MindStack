import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mindstack/core/clock.dart';
import 'package:mindstack/core/ids.dart';
import 'package:mindstack/core/logger.dart';
import 'package:mindstack/domain/app_settings.dart';
import 'package:mindstack/domain/deck_file_picker.dart';
import 'package:mindstack/domain/image_picker.dart';
import 'package:mindstack/domain/pdf_document.dart';
import 'package:mindstack/domain/pdf_file_picker.dart';
import 'package:mindstack/domain/text_recognizer.dart';

/// A [Clock] frozen at a chosen instant that tests can move forward.
final class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) => _now = _now.add(duration);
}

/// An [IdGenerator] returning `prefix-1`, `prefix-2`, ...
final class SequentialIds implements IdGenerator {
  SequentialIds([this.prefix = 'id']);

  final String prefix;
  int _next = 1;

  @override
  String newId() => '$prefix-${_next++}';
}

/// One call recorded by [RecordingLogger].
typedef LoggedError = ({String message, Object error, StackTrace stack});

/// An [AppLogger] that collects its calls for assertions.
final class RecordingLogger implements AppLogger {
  final List<LoggedError> errors = [];

  /// Messages passed to [info].
  final List<String> infos = [];

  @override
  void info(String message) => infos.add(message);

  @override
  void error(String message, Object error, StackTrace stack) {
    errors.add((message: message, error: error, stack: stack));
  }
}

/// A picked file with fixed contents. Set [failReads] to make the next reads
/// throw, and [gate] to hold a read until it completes.
final class FakeDeckFile implements PickedDeckFile {
  FakeDeckFile(this.bytes, {this.reportedLength});

  FakeDeckFile.text(String text) : this(utf8.encode(text));

  FakeDeckFile.fixture(String path)
    : this(File('test/fixtures/mindstack/$path').readAsBytesSync());

  final List<int> bytes;
  final int? reportedLength;
  int failReads = 0;
  Completer<void>? gate;
  int reads = 0;

  @override
  Future<int?> length() async => reportedLength ?? bytes.length;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    await gate?.future;
    if (failReads > 0) {
      failReads--;
      throw const FileSystemException('read failed');
    }
    return Uint8List.fromList(bytes);
  }
}

/// Returns the queued files in order; null means the user cancelled.
final class FakeDeckFilePicker implements DeckFilePicker {
  FakeDeckFilePicker([List<PickedDeckFile?> files = const []])
    : _files = [...files];

  final List<PickedDeckFile?> _files;
  int picks = 0;

  void queue(PickedDeckFile? file) => _files.add(file);

  @override
  Future<PickedDeckFile?> pick() async {
    picks++;
    return _files.isEmpty ? null : _files.removeAt(0);
  }
}

/// A [TextRecognizer] that returns queued results and records calls
final class FakeTextRecognizer implements TextRecognizer {
  FakeTextRecognizer([List<Object> results = const []])
    : _results = [...results];

  final List<Object> _results;

  /// Paths passed to [recognizeText], in call order
  final List<String> paths = [];

  /// Holds every call until completed; set it to test loading states
  Completer<void>? gate;

  int closes = 0;

  void queue(RecognitionResult result) => _results.add(result);

  void queueError(Object error) => _results.add(error);

  @override
  Future<RecognitionResult> recognizeText(String imagePath) async {
    paths.add(imagePath);
    await gate?.future;
    if (_results.isEmpty) {
      return const RecognitionFailure(RecognitionFailureKind.noText);
    }
    final next = _results.removeAt(0);
    if (next is RecognitionResult) return next;
    Error.throwWithStackTrace(next, StackTrace.current);
  }

  @override
  Future<void> close() async => closes++;
}

final class FakePickedImage implements PickedImage {
  const FakePickedImage(this.path);

  @override
  final String path;
}

/// Returns queued pick results in order; an empty queue cancels
final class FakeImagePicker implements ImagePicker {
  FakeImagePicker([List<Object> results = const []]) : _results = [...results];

  final List<Object> _results;

  int galleryCalls = 0;
  int cameraCalls = 0;

  Completer<void>? gate;

  void queue(ImagePickResult result) => _results.add(result);

  void queueError(Object error) => _results.add(error);

  @override
  Future<ImagePickResult> pickGallery() async {
    galleryCalls++;
    return _next();
  }

  @override
  Future<ImagePickResult> pickCamera() async {
    cameraCalls++;
    return _next();
  }

  Future<ImagePickResult> _next() async {
    await gate?.future;
    if (_results.isEmpty) return ImagesPicked(const []);
    final next = _results.removeAt(0);
    if (next is ImagePickResult) return next;
    Error.throwWithStackTrace(next, StackTrace.current);
  }
}

final class FakeAppSettings implements AppSettings {
  FakeAppSettings({this.result = true});

  bool result;
  int opens = 0;

  @override
  Future<bool> open() async {
    opens++;
    return result;
  }
}

final class FakePickedPdf implements PickedPdf {
  FakePickedPdf({this.path = '/tmp/lecture.pdf', this.size = 1024});

  final String path;
  final int? size;

  @override
  Future<int?> length() async => size;

  @override
  Future<String> localPath() async => path;
}

/// Returns the queued files in order; an empty queue cancels
final class FakePdfFilePicker implements PdfFilePicker {
  FakePdfFilePicker([List<PickedPdf?> files = const []]) : _files = [...files];

  final List<PickedPdf?> _files;
  int picks = 0;

  @override
  Future<PickedPdf?> pick() async {
    picks++;
    return _files.isEmpty ? null : _files.removeAt(0);
  }
}

final class FakeRenderedPage implements RenderedPage {
  FakeRenderedPage(this.path, this._deleted);

  @override
  final String path;

  final List<String> _deleted;

  @override
  Future<void> delete() async => _deleted.add(path);
}

/// A PDF whose pages are given as text. An empty string is a scanned page;
/// an [Exception] makes reading that page's text throw.
final class FakeOpenPdf implements OpenPdf {
  FakeOpenPdf(this.pages, {this.renderFailures = const {}});

  /// [count] pages, each with its own labelled card
  FakeOpenPdf.cards(int count)
    : this([for (var i = 1; i <= count; i++) 'Q: What is $i?\nA: Answer $i']);

  final List<Object> pages;
  final Set<int> renderFailures;

  final List<int> textReads = [];
  final List<({int page, int maxEdge})> renders = [];
  final List<String> deleted = [];
  int closes = 0;

  /// Holds page text until completed; a test may cancel meanwhile
  Completer<void>? gate;

  /// Only this page waits for [gate]; null means every page
  int? gatedPage;

  @override
  int get pageCount => pages.length;

  @override
  Future<String> pageText(int pageNumber) async {
    textReads.add(pageNumber);
    if (gatedPage == null || gatedPage == pageNumber) await gate?.future;
    final page = pages[pageNumber - 1];
    if (page is String) return page;
    Error.throwWithStackTrace(page, StackTrace.current);
  }

  @override
  Future<RenderedPage> renderPage(
    int pageNumber, {
    required int maxEdge,
  }) async {
    renders.add((page: pageNumber, maxEdge: maxEdge));
    if (renderFailures.contains(pageNumber)) {
      throw StateError('render failed');
    }
    return FakeRenderedPage('/tmp/page-$pageNumber.png', deleted);
  }

  @override
  Future<void> close() async => closes++;
}

/// Returns queued open results in order and records the opened paths
final class FakePdfReader implements PdfReader {
  FakePdfReader([List<Object> results = const []]) : _results = [...results];

  final List<Object> _results;
  final List<String> paths = [];

  @override
  Future<PdfOpenResult> open(String path) async {
    paths.add(path);
    final next = _results.removeAt(0);
    if (next is PdfOpenResult) return next;
    if (next is OpenPdf) return PdfOpened(next);
    Error.throwWithStackTrace(next, StackTrace.current);
  }
}
