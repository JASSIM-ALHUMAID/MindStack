import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:mindstack/domain/failures.dart';

import '../support/container.dart';

/// An [AppDatabase] that counts how often it was closed.
final class _RecordingDatabase extends AppDatabase {
  _RecordingDatabase(super.e);

  int closeCalls = 0;

  @override
  Future<void> close() {
    closeCalls++;
    return super.close();
  }
}

NativeDatabase _failingExecutor() =>
    NativeDatabase.memory(setup: (_) => throw StateError('disk is on fire'));

void main() {
  test('startup seeds an empty database', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = makeContainer(db: db);

    await container.read(appStartupProvider.future);

    expect(await db.select(db.courses).get(), isNotEmpty);
    expect(await db.select(db.decks).get(), isNotEmpty);
  });

  test('startup succeeds twice on the same file without duplicating', () async {
    final dir = await Directory.systemTemp.createTemp('mindstack_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    final firstContainer = makeContainer(db: first);
    await firstContainer.read(appStartupProvider.future);
    final courseCount = (await first.select(first.courses).get()).length;
    final cardCount = (await first.select(first.flashcards).get()).length;
    expect(courseCount, greaterThan(0));
    // Close the first connection before opening the file again.
    firstContainer.dispose();
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    final secondContainer = makeContainer(db: second);
    await secondContainer.read(appStartupProvider.future);

    expect((await second.select(second.courses).get()).length, courseCount);
    expect((await second.select(second.flashcards).get()).length, cardCount);
  });

  test('startup failure surfaces as AppFailure', () async {
    final container = makeContainer(db: AppDatabase(_failingExecutor()));

    await expectLater(
      container.read(appStartupProvider.future),
      throwsA(isA<StorageFailure>()),
    );
  });

  test('Retry reopens a fresh database after a failed open', () async {
    // Retry builds the second database while the first is still closing, which
    // drift reports as a (debug-only) "multiple databases" warning. That
    // overlap is the scenario under test, so silence the warning here.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    final opened = <_RecordingDatabase>[];
    final container = makeContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          final db = _RecordingDatabase(
            opened.isEmpty ? _failingExecutor() : NativeDatabase.memory(),
          );
          opened.add(db);
          ref.onDispose(() => unawaited(db.close()));
          return db;
        }),
      ],
    );

    await expectLater(
      container.read(appStartupProvider.future),
      throwsA(isA<StorageFailure>()),
    );
    expect(opened, hasLength(1));
    expect(opened.single.closeCalls, 0);

    container.invalidate(databaseProvider);
    await container.read(appStartupProvider.future);

    expect(opened, hasLength(2));
    expect(opened.first.closeCalls, 1, reason: 'failed database was closed');
    expect(opened.last.closeCalls, 0);
    expect(await opened.last.select(opened.last.courses).get(), isNotEmpty);
  });
}
