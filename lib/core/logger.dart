import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Records failures with full detail for developers. Users never see this
/// output; they see `AppFailure.userMessage` instead.
abstract interface class AppLogger {
  /// Logs [message] together with the [error] and its [stack].
  void error(String message, Object error, StackTrace stack);
}

/// The production [AppLogger]: reports through [FlutterError] (so crash
/// reporters and the test binding see it) and the `dart:developer` log.
final class FlutterAppLogger implements AppLogger {
  /// Creates a logger that reports through Flutter's error pipeline.
  const FlutterAppLogger();

  /// `dart:developer` severity for errors (matches `Level.SEVERE`).
  static const int _severe = 1000;

  @override
  void error(String message, Object error, StackTrace stack) {
    developer.log(
      message,
      name: 'mindstack',
      level: _severe,
      error: error,
      stackTrace: stack,
    );
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'mindstack',
        context: ErrorDescription(message),
      ),
    );
  }
}
