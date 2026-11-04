import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/core_providers.dart';
import '../domain/failures.dart';

/// Shown for any failure that is not an [AppFailure]. Matches
/// [StorageFailure.userMessage].
const String kGenericFailureMessage = "Couldn't save. Please try again.";

/// The text a user may see for [error]: the failure's own plain-language
/// message, or [kGenericFailureMessage] for anything else. Never the raw
/// exception.
String failureMessage(Object error) =>
    error is AppFailure ? error.userMessage : kGenericFailureMessage;

/// Runs the write [op] and reports its outcome in a SnackBar.
///
/// On success shows [success] when given and returns `true`. On failure logs
/// the error once with full detail, shows [failureMessage] and returns
/// `false`.
///
/// The messenger and logger are captured before awaiting, so the outcome is
/// still reported when the caller's widget is gone by the time [op] finishes
/// (for example a sheet that was closed).
Future<bool> runSave(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() op, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final logger = ref.read(loggerProvider);
  try {
    await op();
  } on Object catch (error, stack) {
    logger.error('Save failed', error, stack);
    messenger.showSnackBar(SnackBar(content: Text(failureMessage(error))));
    return false;
  }
  if (success != null) {
    messenger.showSnackBar(SnackBar(content: Text(success)));
  }
  return true;
}

/// Shown when reading data fails with a storage or unknown error.
const String kGenericLoadFailureMessage =
    "Couldn't load this. Please try again.";

/// The text a user may see when a read of [error] failed. Like
/// [failureMessage] but with load wording for storage and unknown errors.
String loadFailureMessage(Object error) => switch (error) {
  StorageFailure() => kGenericLoadFailureMessage,
  AppFailure() => error.userMessage,
  _ => kGenericLoadFailureMessage,
};
