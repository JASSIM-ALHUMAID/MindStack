# MindStack (SWE 463 Phase 2 starter)

Spaced-repetition study app. Students import lecture material (screenshots, camera photos, PDFs), turn it into flashcards on the device, and review them on a schedule that ends at their exam date. Everything stays on the phone: no account, no server.

This repository is the Phase 2 starter project. It runs on Android (tested by the group), every main screen is reachable, and the core flows (courses, decks, cards, review, quiz, stats) work on local sample data. Import with on-device OCR, read-aloud and study reminders are planned for Phase 3.

## Run it

Requires Flutter 3.47 or newer (Dart 3.13).

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```

Fonts load at start-up, so after pulling changes do a full restart, not a hot reload.

## What works in the starter

- **Navigation:** bottom bar with Inbox, Library, Review, Quiz and Stats. The app opens on Library. Deck Editor is pushed with go_router (`/deck/:deckId`); Android back from another tab returns to Library.
- **Library:** courses with days to exam, decks with card count and mastery. + Course opens the Create Course sheet (title and exam date, with validation). + Deck on a course opens the Create Deck sheet and then the new deck.
- **Deck Editor:** card list, Add Card and Edit Card sheets with validation (editing keeps the card's schedule), delete a card with a confirmation and Undo, Study (reviews this deck), and a ⋮ menu with Merge into another deck (sheet, confirm dialog, works) and Share deck (placeholder).
- **Inbox:** draft cards with source pills and checkmarks, CLEAR, and Save selected → Choose deck sheet, which saves the ticked drafts as cards. Screenshots, PDF, Import a shared deck and EDIT are placeholders.
- **Review:** refreshed due-card queue, deck filtering, saved ratings and review logs, and session summaries showing count, time, pace and next due date.
- **Settings:** TTS toggle and reminder time are saved with shared_preferences and restored at startup.
- **Quiz:** up to five multiple-choice questions built from your stored cards (the right answer plus three answers from other cards, same deck first). A wrong answer is logged as "Again" for that card, so it is due in the next review. Results show score, accuracy, seconds per question and the missed cards; Review weak cards studies exactly those. With fewer than 4 cards the Quiz tab explains that more cards are needed. The quiz is rebuilt when the tab opens unless one is in progress.
- **Stats:** 28-day streak grid (placeholder history), mastery by deck (fl_chart), exam quota planner, weakest cards with Drill now.

Courses, decks, cards, OCR drafts and review logs are stored in a local SQLite database (drift). The sample data in `lib/data/sample_data.dart` is seeded on the first launch only. Library, Deck Editor, Inbox and Stats read live database queries, so they update as soon as a write completes. Review takes a fresh queue snapshot when a session starts and reads each current card live; it does not reorder the queue during a session.

### Known limitations (Phase 3 work)

- Review again repeats the previous queue. Timing does not pause while the app is in the background.
- The Stats streak is placeholder history.
- Draft editing, importing screenshots, PDFs or a shared deck, and sharing a deck show an "arrives in Phase 3" message.
- TTS and reminder settings persist, but speech and reminder notifications are not implemented yet.

## Phase 3 workflow

The Phase 3 plan is in [docs/plan/phase3-plan.md](docs/plan/phase3-plan.md); each task is a GitHub issue in the `Phase 3` milestone.

- One branch per task: `feat/<task>` (for example `feat/database`). Nobody pushes straight to `main`.
- Commit messages: `feat(scope): short summary`, `fix(scope): ...`, `docs: ...`, `test: ...`.
- Every change goes through a pull request that another member reviews. Mention the issue (`Closes #N`) in the PR.
- Sample `.mindstack` files for parser tests and manual import testing: [test/fixtures/mindstack](test/fixtures/mindstack/README.md).

## Folder structure

Layers import downwards only: `core` imports nothing app-level, `domain` imports `core`, `data` imports `domain` and `core`, `application` imports `data`, `domain` and `core`, `presentation` imports `application`, `domain` and `core`.

```text
lib/
  main.dart                    ProviderScope + runApp
  app.dart                     MaterialApp.router
  router.dart                  go_router routes
  route_names.dart             route paths
  theme/app_theme.dart         Material 3 theme, colors and fonts from Figma
  core/                        clock, ids, logger, dates (no app imports)
  domain/                      enums, failures, scheduler, quiz builder, repository interfaces
    models/                    Course, Deck, DeckStats, Flashcard, DraftCard, ReviewLog, ReviewResult, QuizQuestion
  data/                        drift implementation of the domain interfaces
    database/                  AppDatabase, tables, converters, generated app_database.g.dart
    repositories/              drift library, card, draft and review log repositories
    drift_transaction_runner.dart, failure_mapping.dart, mappers.dart
    seed.dart, sample_data.dart
  application/                 Riverpod providers, command classes, startup, review and quiz notifiers
  presentation/                format.dart, save_feedback.dart
    screens/                   app_shell, library, deck_editor, inbox, review, quiz, stats
    widgets/                   app_gate, async_value_view, common, create_course_sheet, create_deck_sheet, add_card_sheet (shared CardForm), edit_card_sheet, confirm_delete_dialog
assets/fonts/                  Newsreader, Inter, JetBrains Mono + licenses
test/
  domain/ data/                unit tests, and repository tests on an in-memory database
  application/                 command, review, settings and startup tests
  presentation/                widget tests
  support/                     shared test fakes, container and database helpers
  fixtures/mindstack/          sample .mindstack files
android/ ios/ web/ ...         platform folders generated by flutter create
```

## Packages

| Package | Purpose | License | Status |
| --- | --- | --- | --- |
| flutter_riverpod | Shared state management (the only third-party state package) | MIT | In use |
| go_router | Navigation and routes | BSD-3-Clause | In use |
| fl_chart | Progress charts (mastery by deck) | MIT | In use |
| lucide_icons_flutter | Lucide icons, the same set as the Figma file | MIT | In use |
| drift | Type-safe SQLite database | MIT | In use |
| drift_flutter | Opens the drift database on Android, iOS and desktop | MIT | In use |
| path_provider | Finds the app's storage folder for the database file | BSD-3-Clause | In use |
| sqlite3 | Reads SQLite error codes to show clear save errors | MIT | In use |
| uuid | Generates unique ids | MIT | In use |
| shared_preferences | Saves TTS and reminder settings | BSD-3-Clause | In use |
| flutter_lints | Lint rules | BSD-3-Clause | In use (dev) |
| drift_dev | Generates the drift database code | MIT | In use (dev) |
| build_runner | Runs the code generators | BSD-3-Clause | In use (dev) |

The generated drift code (`lib/data/database/app_database.g.dart`) is committed, so a fresh checkout runs after `flutter pub get` with no build step. After changing a table, run `dart run build_runner build --delete-conflicting-outputs` and commit the result.

Planned for Phase 3 (not added yet): image_picker and file_picker for import, google_mlkit_text_recognition for on-device OCR, flutter_tts for read-aloud, flutter_local_notifications for study reminders, share_plus for sharing decks as .mindstack files. Each will be recorded here with its purpose and license when it is added.

## Fonts and icons

The app bundles the three fonts used in the Figma file, so it works offline:

| Font | Used for | License |
| --- | --- | --- |
| Newsreader SemiBold | Screen and card titles | SIL Open Font License 1.1 |
| JetBrains Mono | Small uppercase labels and pills | SIL Open Font License 1.1 |
| Inter (Regular, Medium) | Body text and buttons | SIL Open Font License 1.1 |

The files in `assets/fonts/` are static weights cut from the Google Fonts variable fonts; each font's license is next to it (`OFL-*.txt`). Icons are Lucide icons (lucide.dev, ISC License), the same set used in the Figma file, provided by the lucide_icons_flutter package (MIT).

## Design

Figma: https://www.figma.com/design/KAn2gOCkXUHv5M9FcC4rlW/SWE463?node-id=0-1&p=f&t=ej3erY94YMC1eWmT-0

## AI use disclosure

Claude (Anthropic) was the only AI tool used. It helped draft parts of the technical plan, the navigation diagram and some of the starter Flutter code.

## Team

SWE 463, Group 03

| Name | Student ID |
| --- | --- |
| Firas Almashama | 202263160 |
| Jassim Alhumaid | 202257400 |
| Muhannad AlMelaifi | 202253960 |
| Ibrahim Almuhanna | 202178330 |