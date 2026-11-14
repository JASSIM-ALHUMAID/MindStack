# MindStack (SWE 463 Phase 3 prototype)

Spaced-repetition study app. Students import lecture material (screenshots, camera photos, PDFs), turn it into flashcards on the device, and review them on a schedule that ends at their exam date. Everything stays on the phone: no account, no server.

This repository is the Phase 3 working prototype. It runs on Android (tested by the group on a physical phone). Courses, decks, cards, drafts, review history and settings are saved on the device and are still there after a restart.

## Run it

Requires Flutter 3.47 or newer (Dart 3.13) and an Android phone or emulator.

```bash
git clone https://github.com/JASSIM-ALHUMAID/MindStack
cd MindStack
git checkout phase-3
flutter pub get
flutter run
flutter test
flutter analyze
```

The generated drift code is committed, so no build step is needed. To try the Inbox import, push the sample files to the phone: `adb push test/fixtures/mindstack/valid/ /sdcard/Download/`, then use Import a shared deck in the Inbox.

Fonts load at start-up, so after pulling changes do a full restart, not a hot reload.

## Implemented Phase 3 features

- **Navigation:** bottom bar with Inbox, Library, Review, Quiz and Stats. The app opens on Library. Deck Editor is pushed with go_router (`/deck/:deckId`); Android back from another tab returns to Library.
- **Library (F3):** courses with days to exam, decks with card count and mastery. + Course opens the Create Course sheet (title and exam date, with validation). + Deck on a course opens the Create Deck sheet and then the new deck.
- **Deck Editor (F4):** card list, Add Card and Edit Card sheets with validation (editing keeps the card's schedule), delete a card with a confirmation and Undo, Study (reviews this deck), and a ⋮ menu with Merge into another deck (sheet, confirm dialog, works) and Share deck (placeholder, not built yet).
- **Inbox (F2, shared decks):** Import a shared deck turns a `.mindstack` file into drafts, with loading and error states (Retry, Choose another file). Drafts can be edited, ticked, swiped to delete (with Undo) and saved to a deck. Screenshots, photos and PDF (OCR) import are not built yet.
- **Review (F5, in progress):** refreshed due-card queue, deck filtering, saved ratings and review logs, and session summaries showing count, time, pace and next due date.
- **Settings:** TTS toggle and reminder time are saved with shared_preferences and restored at startup.
- **Quiz (F6):** up to five multiple-choice questions built from your stored cards (the right answer plus three answers from other cards, same deck first). A wrong answer is logged as "Again" for that card, so it is due in the next review. Results show score, accuracy, seconds per question and the missed cards; Review weak cards studies exactly those. With fewer than 4 cards the Quiz tab explains that more cards are needed. The quiz is rebuilt when the tab opens unless one is in progress.
- **Stats (F7):** study streak from the review logs (current and best streak, and a 28-day grid of the days with a review), mastery by deck (fl_chart, average weighted by card count), exam quota planner with inline messages for an invalid total or a past date, and the 3 weakest reviewed cards with Drill now (starts Review with exactly those cards). Empty states when nothing has been reviewed yet.

## Data source

All data is local. Courses, decks, cards, OCR drafts and review logs are stored in a local SQLite database (drift). The sample data in `lib/data/sample_data.dart` is seeded on the first launch only. Library, Deck Editor, Inbox and Stats read live database queries, so they update as soon as a write completes. Review takes a fresh queue snapshot when a session starts and reads each current card live; it does not reorder the queue during a session.

## Known issues

- Review again repeats the previous queue. Timing does not pause while the app is in the background.
- Share deck is a placeholder, so `.mindstack` files come from `test/fixtures/mindstack` for now.
- Undoing a draft delete puts it at the end of the list.
- Arabic (right-to-left) text displays in the wrong order.
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
  domain/                      enums, failures, scheduler, quiz builder, streak, .mindstack file format, repository and file picker interfaces
    models/                    Course, Deck, DeckStats, Flashcard, DraftCard, ReviewLog, ReviewResult, QuizQuestion
  data/                        drift implementation of the domain interfaces
    database/                  AppDatabase, tables, converters, generated app_database.g.dart
    repositories/              drift library, card, draft and review log repositories
    drift_transaction_runner.dart, failure_mapping.dart, mappers.dart
    platform_deck_file_picker.dart
    seed.dart, sample_data.dart
  application/                 Riverpod providers, command classes, startup, stats, review, quiz and deck import notifiers
  presentation/                format.dart, save_feedback.dart
    screens/                   app_shell, library, deck_editor, inbox, review, quiz, stats
    widgets/                   app_gate, async_value_view, common, create_course_sheet, create_deck_sheet, add_card_sheet (shared CardForm), edit_card_sheet, edit_draft_sheet, confirm_delete_dialog
assets/fonts/                  Newsreader, Inter, JetBrains Mono + licenses
test/
  domain/ data/                unit tests, and repository tests on an in-memory database
  application/                 command, review, quiz, stats, settings and startup tests
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
| file_picker | Picks `.mindstack` files to import | MIT | In use |
| flutter_lints | Lint rules | BSD-3-Clause | In use (dev) |
| drift_dev | Generates the drift database code | MIT | In use (dev) |
| build_runner | Runs the code generators | BSD-3-Clause | In use (dev) |

The generated drift code (`lib/data/database/app_database.g.dart`) is committed, so a fresh checkout runs after `flutter pub get` with no build step. After changing a table, run `dart run build_runner build --delete-conflicting-outputs` and commit the result.

Planned (not added yet): image_picker for photo import, google_mlkit_text_recognition for on-device OCR, flutter_tts for read-aloud, flutter_local_notifications for study reminders, share_plus for sharing decks as .mindstack files. Each will be recorded here with its purpose and license when it is added.

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

Claude (Anthropic) was used in this project. It was used to enhance the overall design and architecture of the project, and it helped in creating the tests.

## Team

SWE 463, Group 03

| Name | Student ID |
| --- | --- |
| Firas Almashama | 202263160 |
| Jassim Alhumaid | 202257400 |
| Muhannad AlMelaifi | 202253960 |
| Ibrahim Almuhanna | 202178330 |