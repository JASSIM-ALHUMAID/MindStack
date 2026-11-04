import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/presentation/screens/deck_editor_screen.dart';

import '../support/container.dart';
import '../support/pump.dart';

void main() {
  testWidgets('deck editor shows not-found state when the deck is deleted', (
    tester,
  ) async {
    final container = makeContainer();
    await container.read(appStartupProvider.future);
    final library = container.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deckId = await library.createDeck(courseId: course, title: 'Doomed');
    await container
        .read(cardCommandsProvider)
        .addCard(deckId: deckId, question: 'Q1', answer: 'A1');

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('library home')),
        ),
        GoRoute(
          path: '/deck/:id',
          builder: (_, state) =>
              DeckEditorScreen(deckId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpRouter(tester, container, router);
    router.push<void>('/deck/$deckId').ignore();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(find.text('Doomed'), findsOneWidget);
    expect(find.text('Q1'), findsOneWidget);

    await library.deleteDeck(deckId);
    await tester.pump();
    await tester.pump();

    expect(find.text('This deck no longer exists.'), findsOneWidget);
    expect(find.text('Q1'), findsNothing);

    await tester.tap(find.text('Back to Library'));
    await tester.pumpAndSettle();

    expect(find.text('library home'), findsOneWidget);
  });

  testWidgets('deleting a card removes it and confirms', (tester) async {
    final container = makeContainer();
    await container.read(appStartupProvider.future);
    final library = container.read(libraryCommandsProvider);
    final course = await library.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    final deckId = await library.createDeck(courseId: course, title: 'Deck');
    await container
        .read(cardCommandsProvider)
        .addCard(deckId: deckId, question: 'Q1', answer: 'A1');

    await pumpInApp(tester, container, DeckEditorScreen(deckId: deckId));
    await tester.pump();
    await tester.pump();
    expect(find.text('Q1'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Q1'), findsNothing);
    expect(find.text('Card deleted'), findsOneWidget);
    expect(find.text('No cards yet. Tap + Card to add one.'), findsOneWidget);
  });
}
