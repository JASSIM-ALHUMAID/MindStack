import 'package:mindstack/core/clock.dart';
import 'package:mindstack/core/ids.dart';
import 'package:mindstack/core/logger.dart';

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

  @override
  void error(String message, Object error, StackTrace stack) {
    errors.add((message: message, error: error, stack: stack));
  }
}
