import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/presentation/widgets/async_value_view.dart';

import '../support/container.dart';
import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  Widget view(AsyncValue<int> value) =>
      AsyncValueView<int>(value: value, data: (n) => Text('value $n'));

  testWidgets('shows a spinner while loading and the data when ready', (
    tester,
  ) async {
    final container = makeContainer();

    await pumpInApp(tester, container, view(const AsyncLoading<int>()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpInApp(tester, container, view(const AsyncData(7)));
    expect(find.text('value 7'), findsOneWidget);
  });

  testWidgets('shows the failure message, never the raw error, and logs a '
      'distinct error once', (tester) async {
    final logger = RecordingLogger();
    final container = makeContainer(
      overrides: [loggerProvider.overrideWithValue(logger)],
    );
    final error = StateError('secret detail');
    final value = AsyncError<int>(error, StackTrace.current);

    await pumpInApp(tester, container, view(value));
    await pumpInApp(tester, container, view(value));
    await tester.pump();

    expect(find.text("Couldn't load this. Please try again."), findsOneWidget);
    expect(find.textContaining('secret detail'), findsNothing);
    expect(logger.errors, hasLength(1));

    await pumpInApp(
      tester,
      container,
      view(
        AsyncError<int>(
          const NotFound(entity: 'x', id: '1'),
          StackTrace.current,
        ),
      ),
    );
    expect(find.text('That item no longer exists.'), findsOneWidget);
    expect(logger.errors, hasLength(2));
  });
}
