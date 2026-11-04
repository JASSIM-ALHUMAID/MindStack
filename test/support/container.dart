import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/services.dart';
import 'package:mindstack/core/clock.dart';
import 'package:mindstack/core/ids.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'test_database.dart';

/// Builds a [ProviderContainer] wired to an in-memory database, a fixed clock,
/// sequential ids and a recording logger. The container (and so the database)
/// is disposed when the test ends. [overrides] are applied last and win.
ProviderContainer makeContainer({
  AppDatabase? db,
  Clock? clock,
  IdGenerator? ids,
  List<Override> overrides = const [],
  Map<String, Object> initialPreferences = const {},
}) {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWith((ref) {
        final database = db ?? openTestDatabase();
        // Disposal is synchronous; the close is started and not awaited.
        ref.onDispose(() => unawaited(database.close()));
        return database;
      }),
      clockProvider.overrideWithValue(
        clock ?? FixedClock(DateTime(2026, 11, 4, 12)),
      ),
      idGeneratorProvider.overrideWithValue(ids ?? SequentialIds()),
      loggerProvider.overrideWithValue(RecordingLogger()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}
