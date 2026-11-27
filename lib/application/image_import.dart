import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/image_picker.dart';
import '../domain/models/draft_card.dart';
import 'core_providers.dart';
import 'inbox.dart';
import 'ocr.dart';
import 'services.dart';

final imageImportProvider =
    NotifierProvider<ImageImportNotifier, ImageImportState>(
      ImageImportNotifier.new,
    );

const String kImageImportFailureMessage =
    "Couldn't import these images. Please try again.";

const String kNoCardsMessage = 'No cards were found in this image.';

enum ImageImportKind { gallery, camera }

sealed class ImageImportState {
  const ImageImportState();
}

final class ImageImportIdle extends ImageImportState {
  const ImageImportIdle();
}

final class ImageImportScanning extends ImageImportState {
  const ImageImportScanning();
}

final class ImageImportFailed extends ImageImportState {
  const ImageImportFailed(
    this.message, {
    this.canRetry = false,
    this.canOpenSettings = false,
  });

  /// Safe to show to the user
  final String message;

  final bool canRetry;

  final bool canOpenSettings;
}

sealed class ImageImportResult {
  const ImageImportResult();
}

final class ImageImportSucceeded extends ImageImportResult {
  const ImageImportSucceeded(this.count, this.skipped);

  final int count;

  /// Images that had no readable cards
  final int skipped;
}

final class ImageImportCancelled extends ImageImportResult {
  const ImageImportCancelled();
}

/// Nothing was imported because the pick or scan was refused
final class ImageImportRefused extends ImageImportResult {
  const ImageImportRefused();
}

/// Picks images, recognises them and adds the drafts to the Inbox
final class ImageImportNotifier extends Notifier<ImageImportState> {
  ImageImportKind? _lastKind;
  int _denials = 0;

  @override
  ImageImportState build() => const ImageImportIdle();

  /// Returns the outcome, also exposed in [state] for the UI to watch
  Future<ImageImportResult> import(ImageImportKind kind) async {
    if (state is ImageImportScanning) return const ImageImportCancelled();
    state = const ImageImportScanning();
    _lastKind = kind;
    final picker = ref.read(imagePickerProvider);
    final ImagePickResult picked;
    try {
      picked = kind == ImageImportKind.gallery
          ? await picker.pickGallery()
          : await picker.pickCamera();
    } on Object catch (error, stack) {
      ref.read(loggerProvider).error('Image picker failed', error, stack);
      state = const ImageImportFailed(kImageImportFailureMessage);
      return const ImageImportRefused();
    }

    switch (picked) {
      case ImagesPicked(:final images):
        if (images.isEmpty) {
          _denials = 0;
          state = const ImageImportIdle();
          return const ImageImportCancelled();
        }
        _denials = 0;
        return _scan(
          images,
          source: kind == ImageImportKind.gallery
              ? CardSource.slide
              : CardSource.photo,
        );
      case final ImagePickFailure failure:
        // Android does not tell a denied permission from a permanent one
        // without another plugin, so a second refusal means "open settings"
        final permanent =
            failure.kind == ImagePickFailureKind.permanentlyDenied ||
            _denials >= 1;
        if (failure.kind == ImagePickFailureKind.denied) _denials++;
        state = ImageImportFailed(
          failure.userMessage,
          canRetry: !permanent,
          canOpenSettings: permanent,
        );
        return const ImageImportRefused();
    }
  }

  /// Repeats the last import source after a refusal
  Future<ImageImportResult> retry() =>
      import(_lastKind ?? ImageImportKind.gallery);

  /// Returns false when no settings page could be opened
  Future<bool> openSettings() => ref.read(appSettingsProvider).open();

  Future<ImageImportResult> _scan(
    List<PickedImage> images, {
    required CardSource source,
  }) async {
    state = const ImageImportScanning();
    final progress = ref.read(ocrProgressProvider.notifier);
    final importer = ref.read(ocrImporterProvider);
    final drafts = <DraftCard>[];
    var skipped = 0;
    String? lastMessage;
    try {
      for (var i = 0; i < images.length; i++) {
        progress.state = (i + 1) / images.length;
        final label = source == CardSource.slide
            ? 'Screenshot ${i + 1}'
            : 'Photo ${i + 1}';
        final result = await importer.scan(
          imagePath: images[i].path,
          source: source,
          sourceRef: label,
        );
        switch (result) {
          case OcrScanSuccess(drafts: final scanned):
            if (scanned.isEmpty) {
              skipped++;
              lastMessage = kNoCardsMessage;
            } else {
              drafts.addAll(scanned);
            }
          case OcrScanFailure(:final userMessage):
            skipped++;
            lastMessage = userMessage;
        }
      }
      if (drafts.isNotEmpty) {
        await ref.read(inboxCommandsProvider).addDrafts(drafts);
      }
    } on Object catch (error, stack) {
      ref.read(loggerProvider).error('Image import failed', error, stack);
      state = const ImageImportFailed(kImageImportFailureMessage);
      return const ImageImportRefused();
    } finally {
      progress.state = null;
    }
    if (drafts.isEmpty && skipped == images.length) {
      state = ImageImportFailed(lastMessage ?? kImageImportFailureMessage);
      return const ImageImportRefused();
    }
    state = const ImageImportIdle();
    return ImageImportSucceeded(drafts.length, skipped);
  }
}
