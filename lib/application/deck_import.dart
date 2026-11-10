import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/deck_file_picker.dart';
import '../domain/failures.dart';
import '../domain/mindstack_file.dart';
import 'core_providers.dart';
import 'inbox.dart';
import 'services.dart';

/// Far above any real deck (1,000 cards is about 300 KB).
const int maxDeckFileBytes = 2 * 1024 * 1024;

sealed class DeckImportState {
  const DeckImportState();
}

final class ImportIdle extends DeckImportState {
  const ImportIdle();
}

final class ImportReading extends DeckImportState {
  const ImportReading();
}

final class ImportFailed extends DeckImportState {
  const ImportFailed(this.message);

  /// Safe to show to the user.
  final String message;
}

final deckImportProvider =
    NotifierProvider<DeckImportNotifier, DeckImportState>(
      DeckImportNotifier.new,
    );

/// Picks a `.mindstack` file and adds its cards to the Inbox as drafts.
final class DeckImportNotifier extends Notifier<DeckImportState> {
  PickedDeckFile? _lastFile;

  @override
  DeckImportState build() => const ImportIdle();

  /// Returns the imported deck, or null if the user cancelled, an import is
  /// already running, or it failed (then [state] is [ImportFailed]).
  Future<MindstackFile?> pickAndImport() async {
    if (state is ImportReading) return null;
    final PickedDeckFile? file;
    try {
      file = await ref.read(deckFilePickerProvider).pick();
    } catch (e, s) {
      ref.read(loggerProvider).error('File picker failed', e, s);
      state = const ImportFailed("Couldn't open the file picker.");
      return null;
    }
    if (file == null) return null;
    _lastFile = file;
    return _import(file);
  }

  /// Imports the last picked file again.
  Future<MindstackFile?> retry() async {
    final file = _lastFile;
    if (file == null || state is ImportReading) return null;
    return _import(file);
  }

  Future<MindstackFile?> _import(PickedDeckFile file) async {
    state = const ImportReading();
    try {
      final size = await file.length();
      if (size != null && size > maxDeckFileBytes) {
        throw const InvalidInput(
          field: 'file',
          reason: 'This file is too large to be a deck.',
        );
      }
      final deck = await ref
          .read(inboxCommandsProvider)
          .importDeck(_decode(await file.readAsBytes()));
      state = const ImportIdle();
      return deck;
    } on AppFailure catch (e) {
      ref.read(loggerProvider).info('Import refused: ${e.userMessage}');
      state = ImportFailed(e.userMessage);
    } catch (e, s) {
      ref.read(loggerProvider).error('Import failed', e, s);
      state = const ImportFailed("Couldn't read the file. Try again.");
    }
    return null;
  }

  static String _decode(List<int> bytes) {
    try {
      final text = utf8.decode(bytes);
      // Windows Notepad may start the file with a byte order mark.
      return text.startsWith('﻿') ? text.substring(1) : text;
    } on FormatException {
      throw const InvalidInput(
        field: 'file',
        reason: "This isn't a MindStack deck file.",
      );
    }
  }
}
