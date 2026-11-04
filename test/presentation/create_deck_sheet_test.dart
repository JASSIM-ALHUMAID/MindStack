import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/presentation/widgets/create_deck_sheet.dart';

import '../support/container.dart';
import '../support/pump.dart';

void main() {
  testWidgets('duplicate deck title shows its message inside the open sheet', (
    tester,
  ) async {
    final container = makeContainer();
    await container.read(appStartupProvider.future);
    final commands = container.read(libraryCommandsProvider);
    final courseId = await commands.createCourse(
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );
    await commands.createDeck(courseId: courseId, title: 'Deck');
    final course = Course(
      id: courseId,
      title: 'Course',
      examDate: DateTime(2026, 12, 1),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => showCreateDeckSheet(context, course),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ],
    );
    await pumpRouter(tester, container, router);
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Deck');
    await tester.tap(find.text('Save Deck'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    const message = 'A deck with this name already exists in this course.';
    expect(
      find.text(message).hitTestable(),
      findsOneWidget,
      reason: 'the message must be visible above the modal barrier',
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(message),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Create Deck'),
      findsOneWidget,
      reason: 'sheet stays open',
    );
  });
}
