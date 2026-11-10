import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/core_providers.dart';
import 'package:mindstack/application/deck_import.dart';
import 'package:mindstack/application/inbox.dart';
import 'package:mindstack/domain/deck_file_picker.dart';

import '../support/container.dart';
import '../support/fakes.dart';

ProviderContainer _container(FakeDeckFilePicker picker) => makeContainer(
  overrides: [deckFilePickerProvider.overrideWithValue(picker)],
);

final class _ThrowingPicker implements DeckFilePicker {
  @override
  Future<PickedDeckFile?> pick() async => throw StateError('no activity');
}

Matcher _failedWith(String message) =>
    isA<ImportFailed>().having((s) => s.message, 'message', message);

void main() {
  test('a valid file becomes drafts and the state returns to idle', () async {
    final container = _container(
      FakeDeckFilePicker([
        FakeDeckFile.fixture('valid/01_flutter_widgets.mindstack'),
      ]),
    );

    final deck = await container
        .read(deckImportProvider.notifier)
        .pickAndImport();

    expect(deck?.deckTitle, 'Flutter Widgets');
    expect(container.read(deckImportProvider), isA<ImportIdle>());
    expect(await container.read(draftsProvider.future), hasLength(5));
  });

  test('cancelling the picker changes nothing', () async {
    final container = _container(FakeDeckFilePicker([null]));

    final deck = await container
        .read(deckImportProvider.notifier)
        .pickAndImport();

    expect(deck, isNull);
    expect(container.read(deckImportProvider), isA<ImportIdle>());
    expect(await container.read(draftsProvider.future), isEmpty);
  });

  test('a bad file fails with the parser reason and adds nothing', () async {
    final container = _container(
      FakeDeckFilePicker([
        FakeDeckFile.fixture('invalid/bad_04_empty_cards.mindstack'),
      ]),
    );

    await container.read(deckImportProvider.notifier).pickAndImport();

    expect(
      container.read(deckImportProvider),
      _failedWith('The deck has no cards.'),
    );
    expect(await container.read(draftsProvider.future), isEmpty);
  });

  test('a binary file that is not UTF-8 is refused', () async {
    final container = _container(
      FakeDeckFilePicker([
        FakeDeckFile([0xFF, 0xFE, 0x00, 0x89]),
      ]),
    );

    await container.read(deckImportProvider.notifier).pickAndImport();

    expect(
      container.read(deckImportProvider),
      _failedWith("This isn't a MindStack deck file."),
    );
  });

  test('a file starting with a byte order mark still imports', () async {
    final container = _container(
      FakeDeckFilePicker([
        FakeDeckFile.text(
          '﻿{"deckTitle": "D", "cards": [{"question": "Q", "answer": "A"}]}',
        ),
      ]),
    );

    final deck = await container
        .read(deckImportProvider.notifier)
        .pickAndImport();

    expect(deck?.cards, hasLength(1));
  });

  test('a file over the size limit is refused without being read', () async {
    final file = FakeDeckFile(const [], reportedLength: maxDeckFileBytes + 1);
    final container = _container(FakeDeckFilePicker([file]));

    await container.read(deckImportProvider.notifier).pickAndImport();

    expect(
      container.read(deckImportProvider),
      _failedWith('This file is too large to be a deck.'),
    );
    expect(file.reads, 0);
  });

  test('retry imports the same file after a failed read', () async {
    final file = FakeDeckFile.fixture('valid/04_single_card.mindstack')
      ..failReads = 1;
    final picker = FakeDeckFilePicker([file]);
    final container = _container(picker);
    final notifier = container.read(deckImportProvider.notifier);

    await notifier.pickAndImport();
    expect(
      container.read(deckImportProvider),
      _failedWith("Couldn't read the file. Try again."),
    );

    final deck = await notifier.retry();

    expect(deck?.cards, hasLength(1));
    expect(picker.picks, 1, reason: 'retry does not open the picker');
    expect(container.read(deckImportProvider), isA<ImportIdle>());
  });

  test('cancelling "Choose another file" keeps the error showing', () async {
    final container = _container(
      FakeDeckFilePicker([
        FakeDeckFile.fixture('invalid/bad_01_not_json.mindstack'),
        null,
      ]),
    );
    final notifier = container.read(deckImportProvider.notifier);

    await notifier.pickAndImport();
    await notifier.pickAndImport();

    expect(container.read(deckImportProvider), isA<ImportFailed>());
  });

  test('a picker that throws shows an error instead of crashing', () async {
    final container = makeContainer(
      overrides: [deckFilePickerProvider.overrideWithValue(_ThrowingPicker())],
    );

    await container.read(deckImportProvider.notifier).pickAndImport();

    expect(
      container.read(deckImportProvider),
      _failedWith("Couldn't open the file picker."),
    );
  });

  test('a second import while reading is ignored', () async {
    final file = FakeDeckFile.fixture('valid/04_single_card.mindstack')
      ..gate = Completer<void>();
    final picker = FakeDeckFilePicker([file, file]);
    final container = _container(picker);
    final notifier = container.read(deckImportProvider.notifier);

    final first = notifier.pickAndImport();
    await pumpEventQueue();
    expect(container.read(deckImportProvider), isA<ImportReading>());
    expect(await notifier.pickAndImport(), isNull);

    file.gate!.complete();
    await first;

    expect(picker.picks, 1);
    expect(await container.read(draftsProvider.future), hasLength(1));
  });
}
