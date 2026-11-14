# Phase 3 change log

## Scope delivered

Phase 3 moved MindStack from an in-memory prototype to a restart-safe study app.

- Added Drift/SQLite persistence, repositories, seed data, migrations, and a startup gate.
- Persisted TTS and reminder preferences with `shared_preferences`.
- Added live Library and Deck Editor flows: create, edit, delete, undo, empty states, merge, and contrast fixes.
- Added review scheduling and `ReviewLog` history, live due queues, session summaries, quiz generation, and history-backed stats.
- Added Inbox draft editing, deletion with undo, and `.mindstack` import.
- Added persisted merge/navigation auditing.
- Added `.mindstack` share export and opt-in read-aloud for review cards.

## Deferred to Phase 4

OCR from screenshots, camera photos, and PDFs; reminder notifications; and full RTL correction remain outside this prototype.

## Verification

```bash
flutter pub get
flutter analyze
flutter test
```

Manual Android checks should include importing `test/fixtures/mindstack/valid/01_flutter_widgets.mindstack`, sharing a populated deck, and toggling TTS while reviewing a card.
