import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/inbox.dart';
import 'package:mindstack/application/ocr.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/data/drift_transaction_runner.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/image_picker.dart';
import 'package:mindstack/domain/models/draft_card.dart';
import 'package:mindstack/domain/pdf_document.dart';
import 'package:mindstack/domain/pdf_file_picker.dart';
import 'package:mindstack/domain/repositories.dart';
import 'package:mindstack/domain/text_recognizer.dart';
import 'package:mindstack/presentation/screens/inbox_screen.dart';

import '../support/container.dart';
import '../support/fakes.dart';
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

typedef Harness = ({
  FakeImagePicker picker,
  FakeTextRecognizer recognizer,
  FakeAppSettings settings,
  ProviderContainer container,
});

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

  group('import a shared deck', () {
    const importLink = 'Import a shared deck (.mindstack)';

    Future<FakeDeckFilePicker> pumpInbox(
      WidgetTester tester,
      List<FakeDeckFile?> files,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final picker = FakeDeckFilePicker(files);
      final container = makeContainer(
        overrides: [deckFilePickerProvider.overrideWithValue(picker)],
      );
      await pumpInApp(tester, container, const InboxScreen());
      await tester.pumpAndSettle();
      return picker;
    }

    testWidgets('a valid file shows its drafts and a toast', (tester) async {
      await pumpInbox(tester, [
        FakeDeckFile.fixture('valid/01_flutter_widgets.mindstack'),
      ]);

      await tester.tap(find.text(importLink));
      await tester.pumpAndSettle();

      expect(
        find.text('5 drafts imported from Flutter Widgets'),
        findsOneWidget,
      );
      expect(find.text('What is a Widget?'), findsOneWidget);
      expect(find.text('Save selected (5) to a deck'), findsOneWidget);
    });

    testWidgets('Arabic drafts read right to left', (tester) async {
      await pumpInbox(tester, [
        FakeDeckFile.fixture('valid/05_unicode_and_long_text.mindstack'),
      ]);

      await tester.tap(find.text(importLink));
      await tester.pumpAndSettle();

      const arabic = 'ما هو الـ Widget في Flutter؟';
      const english =
          'Edge case: a very long answer that should wrap and truncate '
          'cleanly in a draft card?';
      expect(
        tester.widget<Text>(find.text(arabic)).textDirection,
        TextDirection.rtl,
      );
      expect(
        tester.widget<Text>(find.text(english)).textDirection,
        TextDirection.ltr,
      );
      // Both end at the card's right edge; the short Arabic line starts later.
      expect(
        tester.getTopRight(find.text(arabic)).dx,
        closeTo(tester.getTopRight(find.text(english)).dx, 1),
      );
      expect(
        tester.getTopLeft(find.text(arabic)).dx,
        greaterThan(tester.getTopLeft(find.text(english)).dx),
      );
      // The Arabic deck title inside English lines keeps its own order.
      final title =
          '${String.fromCharCode(0x2068)}مراجعة · Unicode & long text'
          '${String.fromCharCode(0x2069)}';
      expect(find.text('3 drafts imported from $title'), findsOneWidget);
      expect(find.text(title.toUpperCase()), findsNWidgets(3));
    });

    testWidgets('shows the loading state while the file is read', (
      tester,
    ) async {
      final file = FakeDeckFile.fixture('valid/04_single_card.mindstack')
        ..gate = Completer<void>();
      await pumpInbox(tester, [file]);

      await tester.tap(find.text(importLink));
      await tester.pump();

      expect(find.text('READING DECK FILE…'), findsOneWidget);
      expect(find.text('No drafts yet. Import something above.'), findsNothing);
      final link = tester.widget<TextButton>(
        find.ancestor(
          of: find.text(importLink),
          matching: find.bySubtype<TextButton>(),
        ),
      );
      expect(link.onPressed, isNull);

      file.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('READING DECK FILE…'), findsNothing);
      expect(find.text('What is go_router?'), findsOneWidget);
    });

    testWidgets('a bad file shows the error card; another file recovers', (
      tester,
    ) async {
      await pumpInbox(tester, [
        FakeDeckFile.fixture('invalid/bad_05_card_missing_answer.mindstack'),
        FakeDeckFile.fixture('valid/04_single_card.mindstack'),
      ]);

      await tester.tap(find.text(importLink));
      await tester.pumpAndSettle();

      expect(find.text("This file couldn't be read"), findsOneWidget);
      expect(find.text('Card 1 has no answer.'), findsOneWidget);
      expect(find.text('Retry import'), findsOneWidget);
      expect(find.text('No drafts yet. Fix the import above.'), findsOneWidget);

      await tester.tap(find.text('Choose another file'));
      await tester.pumpAndSettle();

      expect(find.text("This file couldn't be read"), findsNothing);
      expect(find.text('1 draft imported from One card only'), findsOneWidget);
    });
  });

  testWidgets('swiping a draft deletes it and Undo restores it in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = makeContainer();
    await container.read(draftRepositoryProvider).insertAll([
      for (final id in ['d1', 'd2', 'd3'])
        DraftCard(
          id: id,
          source: CardSource.shared,
          sourceRef: 'Deck',
          question: 'Question $id',
          answer: 'Answer $id',
        ),
    ]);
    await pumpInApp(tester, container, const InboxScreen());
    await tester.pumpAndSettle();
    expect(find.text('Save selected (3) to a deck'), findsOneWidget);

    await tester.drag(find.text('Question d2'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Question d2'), findsNothing);
    expect(find.text('Draft deleted'), findsOneWidget);
    expect(find.text('Save selected (2) to a deck'), findsOneWidget);
    var stored = await container.read(draftsProvider.future);
    expect([for (final d in stored) d.id], ['d1', 'd3']);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Save selected (3) to a deck'), findsOneWidget);
    stored = await container.read(draftsProvider.future);
    expect([for (final d in stored) d.id], ['d1', 'd2', 'd3']);
    final top = [
      for (final id in ['d1', 'd2', 'd3'])
        tester.getTopLeft(find.text('Question $id')).dy,
    ];
    expect(top[0] < top[1] && top[1] < top[2], isTrue, reason: '$top');
  });

  testWidgets('EDIT validates and saves the draft text', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = makeContainer();
    await container.read(draftRepositoryProvider).insertAll([
      const DraftCard(
        id: 'd1',
        source: CardSource.shared,
        sourceRef: 'Deck',
        question: 'Old question',
        answer: 'Old answer',
      ),
    ]);
    await pumpInApp(tester, container, const InboxScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('EDIT'));
    await tester.pumpAndSettle();
    final question = find.widgetWithText(TextFormField, 'Question');
    await tester.enterText(question, '   ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a question'), findsOneWidget);

    await tester.enterText(question, 'New question');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('New question'), findsOneWidget);
    expect(find.text('Old question'), findsNothing);
    final draft = (await container.read(draftsProvider.future)).single;
    expect(draft.question, 'New question');
  });

  group('image import', () {
    const cardText = 'Q: What is osmosis?\nA: Water movement';
    const pickPath = '/tmp/screenshot.png';

    Future<Harness> pumpImages(
      WidgetTester tester, {
      required List<Object> pickResults,
      List<Object> ocrResults = const [
        RecognizedText([RecognizedBlock(cardText)]),
      ],
      bool settingsResult = true,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final picker = FakeImagePicker(pickResults);
      final recognizer = FakeTextRecognizer(ocrResults);
      final settings = FakeAppSettings(result: settingsResult);
      final container = makeContainer(
        overrides: [
          imagePickerProvider.overrideWithValue(picker),
          textRecognizerFactoryProvider.overrideWithValue(() => recognizer),
          appSettingsProvider.overrideWithValue(settings),
        ],
      );
      await pumpInApp(tester, container, const InboxScreen());
      await tester.pumpAndSettle();
      return (
        picker: picker,
        recognizer: recognizer,
        settings: settings,
        container: container,
      );
    }

    testWidgets('Screenshots picks a gallery image and shows its drafts', (
      tester,
    ) async {
      final h = await pumpImages(
        tester,
        pickResults: [
          ImagesPicked([const FakePickedImage(pickPath)]),
        ],
      );

      await tester.tap(find.text('Screenshots'));
      await tester.pumpAndSettle();

      expect(find.text('What is osmosis?'), findsOneWidget);
      expect(find.text('1 draft imported'), findsOneWidget);
      expect(find.text('SLIDE'), findsOneWidget);
      expect(h.recognizer.paths, [pickPath]);
    });

    testWidgets('Take a picture uses the camera and tags drafts as photos', (
      tester,
    ) async {
      final h = await pumpImages(
        tester,
        pickResults: [
          ImagesPicked([const FakePickedImage(pickPath)]),
        ],
      );

      await tester.tap(find.text('Take a picture'));
      await tester.pumpAndSettle();

      expect(find.text('Water movement'), findsOneWidget);
      expect(find.text('PHOTO'), findsOneWidget);
      expect(h.picker.cameraCalls, 1);
      expect(h.picker.galleryCalls, 0);
    });

    testWidgets('cancelling the picker leaves the Inbox empty', (tester) async {
      await pumpImages(tester, pickResults: [ImagesPicked(const [])]);

      await tester.tap(find.text('Screenshots'));
      await tester.pumpAndSettle();

      expect(
        find.text('No drafts yet. Import something above.'),
        findsOneWidget,
      );
      expect(find.textContaining('denied'), findsNothing);
    });

    testWidgets('a denial shows the message and Try again', (tester) async {
      await pumpImages(
        tester,
        pickResults: [const ImagePickFailure(ImagePickFailureKind.denied)],
      );

      await tester.tap(find.text('Take a picture'));
      await tester.pumpAndSettle();

      expect(
        find.text('Photo access was denied. Allow photos to import images.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a second denial offers Open settings', (tester) async {
      final h = await pumpImages(
        tester,
        pickResults: [
          const ImagePickFailure(ImagePickFailureKind.denied),
          const ImagePickFailure(ImagePickFailureKind.denied),
        ],
      );

      await tester.tap(find.text('Take a picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a picture'));
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(h.settings.opens, 1);
    });

    testWidgets('no text shows the recogniser message', (tester) async {
      await pumpImages(
        tester,
        pickResults: [
          ImagesPicked([const FakePickedImage(pickPath)]),
        ],
        ocrResults: const [RecognitionFailure(RecognitionFailureKind.noText)],
      );

      await tester.tap(find.text('Screenshots'));
      await tester.pumpAndSettle();

      expect(find.text('No text was found in this image.'), findsOneWidget);
      expect(find.text('What is osmosis?'), findsNothing);
    });

    testWidgets('image buttons are disabled while a scan runs', (tester) async {
      final gate = Completer<void>();
      final h = await pumpImages(
        tester,
        pickResults: [
          ImagesPicked([const FakePickedImage(pickPath)]),
        ],
      );
      h.recognizer.gate = gate;

      await tester.tap(find.text('Screenshots'));
      await tester.pump();

      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Screenshots'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('What is osmosis?'), findsOneWidget);
    });
  });

  group('PDF import', () {
    Future<({FakePdfFilePicker picker, FakePdfReader reader})> pumpPdf(
      WidgetTester tester, {
      List<PickedPdf?>? files,
      required List<Object> opens,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final picker = FakePdfFilePicker(files ?? [FakePickedPdf()]);
      final reader = FakePdfReader(opens);
      final container = makeContainer(
        overrides: [
          pdfFilePickerProvider.overrideWithValue(picker),
          pdfReaderProvider.overrideWithValue(reader),
          textRecognizerFactoryProvider.overrideWithValue(
            FakeTextRecognizer.new,
          ),
        ],
      );
      await pumpInApp(tester, container, const InboxScreen());
      await tester.pumpAndSettle();
      return (picker: picker, reader: reader);
    }

    OutlinedButton button(WidgetTester tester, String label) =>
        tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(OutlinedButton),
          ),
        );

    testWidgets('PDF imports the cards and reports them', (tester) async {
      await pumpPdf(
        tester,
        opens: [
          FakeOpenPdf([
            'Title slide for the lecture',
            'Q: What is the powerhouse of the cell?\nA: The mitochondria',
          ]),
        ],
      );

      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      expect(find.text('What is the powerhouse of the cell?'), findsOneWidget);
      expect(find.text('PAGE 2'), findsOneWidget);
      expect(find.text('PDF'), findsWidgets);
      expect(find.text('1 draft imported'), findsOneWidget);
    });

    testWidgets('shows the page being read and blocks other imports', (
      tester,
    ) async {
      final pdf = FakeOpenPdf.cards(2)..gate = Completer<void>();
      await pumpPdf(tester, opens: [pdf]);

      await tester.tap(find.text('PDF'));
      await tester.pump();

      expect(find.text('READING PAGE 1 OF 2'), findsOneWidget);
      expect(button(tester, 'PDF').onPressed, isNull);
      expect(button(tester, 'Screenshots').onPressed, isNull);
      pdf.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('READING PAGE 1 OF 2'), findsNothing);
      expect(find.text('2 drafts imported'), findsOneWidget);
    });

    Future<void> cancelAfterFirstPage(WidgetTester tester) async {
      final pdf = FakeOpenPdf.cards(3)..gate = Completer<void>();
      await pumpPdf(tester, opens: [pdf]);
      await tester.tap(find.text('PDF'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('STOPPING AFTER THIS PAGE…'), findsOneWidget);
      pdf.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Keep the drafts found so far?'), findsOneWidget);
      expect(
        find.text('1 draft was found in the first 1 of 3 pages.'),
        findsOneWidget,
      );
    }

    testWidgets('Cancel then Keep adds the drafts read so far', (tester) async {
      await cancelAfterFirstPage(tester);

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();

      expect(find.text('What is 1?'), findsOneWidget);
      expect(find.text('What is 2?'), findsNothing);
      expect(find.text('1 draft imported'), findsOneWidget);
    });

    testWidgets('Cancel then Discard adds nothing', (tester) async {
      await cancelAfterFirstPage(tester);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('What is 1?'), findsNothing);
      expect(
        find.text('No drafts yet. Import something above.'),
        findsOneWidget,
      );
    });

    testWidgets('a refused PDF offers another file but no retry', (
      tester,
    ) async {
      final h = await pumpPdf(
        tester,
        files: [
          FakePickedPdf(),
          FakePickedPdf(path: '/tmp/other.pdf'),
        ],
        opens: [
          const PdfOpenFailure(PdfOpenFailureKind.passwordProtected),
          FakeOpenPdf.cards(1),
        ],
      );

      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      expect(find.text("This PDF couldn't be imported"), findsOneWidget);
      expect(
        find.text(
          'This PDF is password-protected. Remove the password and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry import'), findsNothing);
      expect(find.text('No drafts yet. Fix the import above.'), findsOneWidget);

      await tester.tap(find.text('Choose another file'));
      await tester.pumpAndSettle();

      expect(h.reader.paths, ['/tmp/lecture.pdf', '/tmp/other.pdf']);
      expect(find.text('What is 1?'), findsOneWidget);
      expect(find.text("This PDF couldn't be imported"), findsNothing);
    });
  });
}
