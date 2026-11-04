import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/presentation/widgets/app_gate.dart';

import '../support/container.dart';
import '../support/fakes.dart';

AppDatabase _db(NativeDatabase executor) =>
    AppDatabase(DatabaseConnection(executor, closeStreamsSynchronously: true));

void main() {
  testWidgets('AppGate shows a spinner, then the error without the raw '
      'exception, and Retry opens the app', (tester) async {
    // Retry builds the second database while the first is still closing, which
    // drift reports as a debug-only warning. That overlap is the scenario.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    final logger = RecordingLogger();
    var opened = 0;
    final container = makeContainer(
      overrides: [
        loggerProvider.overrideWithValue(logger),
        databaseProvider.overrideWith((ref) {
          final db = _db(
            opened++ == 0
                ? NativeDatabase.memory(
                    setup: (_) => throw StateError('disk is on fire'),
                  )
                : NativeDatabase.memory(),
          );
          ref.onDispose(() => unawaited(db.close()));
          return db;
        }),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppGate(child: Text('app is open'))),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text("MindStack couldn't open your data."), findsOneWidget);
    expect(
      find.text('Try again. If this keeps happening, restart the app.'),
      findsOneWidget,
    );
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.textContaining('disk is on fire'), findsNothing);
    expect(find.text('app is open'), findsNothing);
    expect(logger.errors, hasLength(1));
    expect(logger.errors.single.error, isA<StorageFailure>());

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('app is open'), findsOneWidget);
    expect(opened, 2);
    expect(logger.errors, hasLength(1));
  });
}
