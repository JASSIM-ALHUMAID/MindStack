# Group 03 — MindStack Phase 3 Prototype

## Cover

SWE 463 · Phase 3 working prototype · Group 03

MindStack is a local-first spaced-repetition study app. Students import lecture material as decks, review cards on an SM-2-style schedule, and inspect progress without an account or server.

## Phase 2 changes

Phase 3 added Drift/SQLite persistence, a startup gate, import-as-draft feeding the Inbox flow, and the Task 9 share/read-aloud extension. OCR for screenshots, camera photos, and PDFs was moved to Phase 4.

## Feature coverage

F2 through F8 are implemented. F1 OCR remains deferred. The app includes Library, Deck Editor, Inbox, Review, Quiz, Stats, persisted settings, shared-deck import/export, and optional review read-aloud.

## Working flow

Inbox → Import `.mindstack` → edit a draft → save selected cards → open Deck Editor → Study → rate cards → inspect Stats.

## Screenshots and navigation

The required capture list is in `screenshots/README.md`. Bottom navigation reaches Inbox, Library, Review, Quiz, and Stats. Deck Editor is pushed at `/deck/:deckId`; Android back returns to Library when appropriate. The share sheet and TTS output should be captured on Android because they are platform-owned behaviors.

## State and data

Drift stores courses, decks, cards, drafts, and review logs in SQLite. `shared_preferences` stores TTS and reminder settings. Startup waits for preferences, database open, and seed completion before showing the app. Streams keep Library, Deck Editor, Inbox, and Stats current after writes.

## Quality and known issues

The test suite covers domain rules, repositories, application commands, startup, navigation, widget states, import fixtures, quiz behavior, and review history. Known limitations are deferred OCR, reminder notifications, incomplete RTL display, and no background timing pause during review.

## Contributions

See `contributions.md` for the member and feature record. The Git history is the authoritative commit/PR record.

## Testing and manual demo

```bash
flutter pub get
flutter analyze
flutter test
```

For import testing, use `test/fixtures/mindstack/valid/01_flutter_widgets.mindstack`. On Android, push it with `adb push` to Downloads, import it in Inbox, save the cards, then test sharing and TTS.
