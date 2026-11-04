import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/data/drift_transaction_runner.dart';
import 'package:mindstack/domain/repositories.dart';
import 'package:mindstack/presentation/screens/inbox_screen.dart';

import '../support/container.dart';
import '../support/pump.dart';

/// Counts calls and holds each one until [release] completes.
final class _GatedRunner implements TransactionRunner {
  _GatedRunner(this._inner);

  final TransactionRunner _inner;
  final Completer<void> release = Completer<void>();
  int calls = 0;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    calls++;
    await release.future;
    return _inner.run(action);
  }
}

void main() {
  testWidgets('Save selected ignores a second tap while saving', (
    tester,
  ) async {
    // Tall viewport so the whole lazy list, including the save button, is built.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late _GatedRunner runner;
    final container = makeContainer(
      overrides: [
        transactionRunnerProvider.overrideWith((ref) {
          runner = _GatedRunner(
            DriftTransactionRunner(ref.watch(databaseProvider)),
          );
          return runner;
        }),
      ],
    );
    await container.read(appStartupProvider.future);
    final db = container.read(databaseProvider);
    final deck = (await db.select(db.decks).get()).first;
    final selected = (await db.select(db.draftCards).get())
        .where((d) => d.selected)
        .length;
    expect(selected, greaterThan(0));

    await pumpInApp(tester, container, const InboxScreen());
    await tester.pump();
    await tester.pump();
    final save = find.text('Save selected ($selected) to a deck');
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.text(deck.title));
    await tester.pumpAndSettle();

    expect(runner.calls, 1);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    expect(runner.calls, 1, reason: 'second tap is ignored while saving');

    runner.release.complete();
    await tester.pump();
    await tester.pump();

    expect(runner.calls, 1);
    expect(find.text('$selected cards saved to ${deck.title}'), findsOneWidget);
    final stored = await (db.select(
      db.flashcards,
    )..where((c) => c.deckId.equals(deck.id))).get();
    expect(stored.length, greaterThanOrEqualTo(selected));
  });

  testWidgets('inbox shows the empty state after CLEAR', (tester) async {
    final container = makeContainer();
    await container.read(appStartupProvider.future);

    await pumpInApp(tester, container, const InboxScreen());
    await tester.pump();
    await tester.tap(find.text('CLEAR'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No drafts yet. Import something above.'), findsOneWidget);
    expect(find.textContaining('0 PENDING'), findsOneWidget);
  });
}
