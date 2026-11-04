import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/services.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/presentation/save_feedback.dart';

import '../support/container.dart';
import '../support/fakes.dart';
import '../support/pump.dart';

Future<RecordingLogger> _runFailing(WidgetTester tester, Object failure) async {
  final logger = RecordingLogger();
  final container = makeContainer(
    overrides: [loggerProvider.overrideWithValue(logger)],
  );
  await pumpInApp(
    tester,
    container,
    Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () => runSave(context, ref, () => Future.error(failure)),
        child: const Text('save'),
      ),
    ),
  );
  await tester.tap(find.text('save'));
  await tester.pump();
  await tester.pump();
  return logger;
}

void main() {
  for (final failure in <AppFailure>[
    const InvalidInput(field: 'title', reason: 'Enter a deck name.'),
    const Conflict(ConflictKind.duplicateTitle),
    const NotFound(entity: 'deck', id: 'd1'),
  ]) {
    testWidgets('${failure.runtimeType} is logged as info, not an error', (
      tester,
    ) async {
      final logger = await _runFailing(tester, failure);

      expect(logger.errors, isEmpty);
      expect(logger.infos, hasLength(1));
      expect(find.text(failure.userMessage), findsOneWidget);
    });
  }

  testWidgets('StorageFailure is logged as an error', (tester) async {
    final logger = await _runFailing(
      tester,
      StorageFailure(StateError('disk full'), StackTrace.current),
    );

    expect(logger.errors, hasLength(1));
    expect(logger.infos, isEmpty);
  });

  testWidgets('a non-AppFailure is logged as an error', (tester) async {
    final logger = await _runFailing(tester, StateError('boom'));

    expect(logger.errors, hasLength(1));
    expect(logger.infos, isEmpty);
  });
}
