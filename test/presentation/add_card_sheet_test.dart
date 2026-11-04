import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/data/repositories/drift_card_repository.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/deck_stats.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/repositories.dart';
import 'package:mindstack/presentation/widgets/add_card_sheet.dart';

import '../support/container.dart';
import '../support/fakes.dart';
import '../support/pump.dart';

/// A [CardRepository] whose inserts fail; everything else is delegated.
final class _FailingInsertCards implements CardRepository {
  _FailingInsertCards(this._inner, this.failure);

  final CardRepository _inner;
  final AppFailure failure;

  @override
  Future<void> insert(Flashcard card) => Future.error(failure);

  @override
  Stream<List<Flashcard>> watchAll() => _inner.watchAll();

  @override
  Stream<List<Flashcard>> watchByDeck(String deckId) =>
      _inner.watchByDeck(deckId);

  @override
  Stream<Map<String, DeckStats>> watchDeckStats() => _inner.watchDeckStats();

  @override
  Future<List<Flashcard>> due({required DateTime now, String? deckId}) =>
      _inner.due(now: now, deckId: deckId);

  @override
  Future<Flashcard> byId(String id) => _inner.byId(id);

  @override
  Future<void> insertAll(List<Flashcard> cards) => _inner.insertAll(cards);

  @override
  Future<void> update(Flashcard card) => _inner.update(card);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<int> moveToDeck({
    required String fromDeckId,
    required String toDeckId,
  }) => _inner.moveToDeck(fromDeckId: fromDeckId, toDeckId: toDeckId);
}

Widget _opener(String deckId) => Builder(
  builder: (context) => TextButton(
    onPressed: () => showAddCardSheet(context, deckId),
    child: const Text('open sheet'),
  ),
);

void main() {
  testWidgets('add card sheet shows the failure message and keeps the sheet '
      'open', (tester) async {
    final logger = RecordingLogger();
    final container = makeContainer(
      overrides: [
        loggerProvider.overrideWithValue(logger),
        cardRepositoryProvider.overrideWith(
          (ref) => _FailingInsertCards(
            DriftCardRepository(ref.watch(databaseProvider)),
            StorageFailure(StateError('disk full'), StackTrace.current),
          ),
        ),
      ],
    );
    await container.read(appStartupProvider.future);
    final course = await container
        .read(libraryCommandsProvider)
        .createCourse(title: 'C', examDate: DateTime(2026, 12, 1));
    final deckId = await container
        .read(libraryCommandsProvider)
        .createDeck(courseId: course, title: 'D');

    await pumpInApp(tester, container, _opener(deckId));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Question'), 'Q');
    await tester.enterText(find.widgetWithText(TextFormField, 'Answer'), 'A');
    await tester.tap(find.text('Save card'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't save. Please try again."), findsOneWidget);
    expect(find.textContaining('disk full'), findsNothing);
    expect(find.text('Add card'), findsOneWidget, reason: 'sheet stays open');
    expect(logger.errors, hasLength(1));
    // The button is usable again for a retry.
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Save card'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('add card sheet validates before saving', (tester) async {
    final container = makeContainer();
    await container.read(appStartupProvider.future);

    await pumpInApp(tester, container, _opener('any'));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save card'));
    await tester.pump();

    expect(find.text('Enter a question'), findsOneWidget);
    expect(find.text('Enter an answer'), findsOneWidget);
  });
}
