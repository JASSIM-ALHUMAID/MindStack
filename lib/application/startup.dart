import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seed.dart';
import '../domain/failures.dart';
import 'core_providers.dart';

/// Opens the database and seeds it on first run. The boot gate watches this;
/// on error it offers Retry, which invalidates [databaseProvider] so a fresh
/// database is opened and this provider rebuilds.
///
/// Fails only with an [AppFailure]: anything else becomes [StorageFailure]
/// with its original stack trace.
final appStartupProvider = FutureProvider<void>((ref) async {
  // Both dependencies are watched before the first await so that a change
  // (such as Retry) always restarts startup.
  final db = ref.watch(databaseProvider);
  final data = ref.watch(seedDataProvider);
  try {
    await db.ensureOpen();
    await seedIfNeeded(db, data);
  } on AppFailure {
    rethrow;
  } on Object catch (error, stack) {
    Error.throwWithStackTrace(StorageFailure(error, stack), stack);
  }
});
