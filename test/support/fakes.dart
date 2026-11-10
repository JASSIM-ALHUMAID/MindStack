import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mindstack/core/clock.dart';
import 'package:mindstack/core/ids.dart';
import 'package:mindstack/core/logger.dart';
import 'package:mindstack/domain/deck_file_picker.dart';

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
