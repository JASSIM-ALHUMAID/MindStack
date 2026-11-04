// `remote.dart` is flagged experimental but is the only public home of
// `DriftRemoteException`, which drift raises for isolate-hosted databases.
// ignore: experimental_member_use
import 'package:drift/remote.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../domain/failures.dart';

const _primaryKeyViolation = 1555;
const _uniqueViolation = 2067;
const _foreignKeyViolation = 787;
const _checkViolation = 275;

/// Runs [body] and translates storage errors into [AppFailure]s so that
/// `SqliteException` and `DriftRemoteException` never leave the data layer.
///
/// [onForeignKey] lets the caller name the missing parent for a foreign key
/// violation; without it a generic [NotFound] is thrown.
Future<T> guard<T>(
  Future<T> Function() body, {
  AppFailure Function()? onForeignKey,
}) async {
  try {
    return await body();
  } on AppFailure {
    rethrow;
  } on Object catch (error, stack) {
    Error.throwWithStackTrace(
      _translate(error, stack, onForeignKey),
      _stackOf(error, stack),
    );
  }
}

/// Maps errors emitted by [source] the same way as [guard], keeping values.
Stream<T> guardStream<T>(
  Stream<T> source, {
  AppFailure Function()? onForeignKey,
}) {
  return source.handleError((Object error, StackTrace stack) {
    if (error is AppFailure) Error.throwWithStackTrace(error, stack);
    Error.throwWithStackTrace(
      _translate(error, stack, onForeignKey),
      _stackOf(error, stack),
    );
  });
}

StackTrace _stackOf(Object error, StackTrace fallback) =>
    error is DriftRemoteException
    ? (error.remoteStackTrace ?? fallback)
    : fallback;

AppFailure _translate(
  Object error,
  StackTrace stack,
  AppFailure Function()? onForeignKey,
) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  if (cause is AppFailure) return cause;
  if (cause is SqliteException) {
    switch (cause.extendedResultCode) {
      case _primaryKeyViolation:
        return const Conflict(ConflictKind.duplicateId);
      case _uniqueViolation:
        return const Conflict(ConflictKind.duplicateTitle);
      case _foreignKeyViolation:
        return onForeignKey?.call() ??
            const NotFound(entity: 'related item', id: '');
      case _checkViolation:
        return const InvalidInput(
          field: 'text',
          reason: 'Some required text is missing.',
        );
    }
  }
  return StorageFailure(cause, _stackOf(error, stack));
}
