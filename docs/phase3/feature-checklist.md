# Phase 3 feature checklist

| Feature | Status | Evidence |
| --- | --- | --- |
| F2 Inbox shared-deck import | Implemented | `lib/application/deck_import.dart`, import tests |
| F3 Library courses/decks | Implemented | Library screen and repository tests |
| F4 Deck Editor | Implemented | Deck Editor screen and widget tests |
| F5 Review and history | Implemented | Review screen and review/session tests |
| F6 Quiz from stored cards | Implemented | Quiz builder and quiz tests |
| F7 Stats from review history | Implemented | Stats screen and stats providers |
| F8 Merge/share/navigation | Implemented | `LibraryCommands.mergeDecks`, share export, navigation tests |
| F1 OCR import | Deferred | Planned Phase 4 work |

## Runtime-state audit

The async flows expose loading, success, empty, and failure states through the shared `AsyncValueView` and screen-specific empty/error copy. Verify these states on Android before submission:

- Inbox loading/error and empty draft list
- Library empty state
- Deck Editor empty state
- Review complete state
- Quiz fewer-than-four-cards empty state
- Stats empty/no-history state

The corresponding screenshot checklist is in `screenshots/README.md`.

## Quality gate

- [x] Generated Drift code is committed.
- [x] No secrets are stored in the repository.
- [x] `.mindstack` encoding excludes interval, ease, due time, repetitions, and mastery.
- [x] TTS is opt-in and stopped when Review is disposed.
- [ ] Android device screenshots captured for the final report.
