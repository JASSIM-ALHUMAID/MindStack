# MindStack Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Phase 2 starter (in-memory sample data) into a persistent, working prototype that has at least 5 of 8 essential features Implemented (62.5% floor, about 69% target counting F7 as In progress) and one complete end-to-end flow.

**Architecture:** Layered `lib/core, domain, data, application, presentation`. A drift (SQLite) database is the single source of truth behind repository interfaces in `domain/`; screens read live `StreamProvider`s and write through command classes. Startup opens and seeds the database behind a loading and error gate. Import and share of `.mindstack` files supplies the draft cards that feed the Inbox, so F2 works without OCR. OCR (F1) is Phase 4.

**Tech Stack:** Flutter 3.47+, Dart ^3.13, flutter_riverpod, go_router, fl_chart, drift (+ drift_flutter, drift_dev, build_runner), path_provider, sqlite3, uuid, shared_preferences, file_picker, share_plus, flutter_test.

**Spec:** `Group03_Phase2_Design.pdf` (approved design, in the parent folder, not in the repo) and `SWE463_Project_Phase_3_Working_Flutter_Prototype.pdf` (Phase 3 brief). Sections 2, 6 and 7 of the design are the source for scope, data and packages.

## Global Constraints

- Riverpod is the only shared-state package (`flutter_riverpod`). Card-flipped, form text and planner inputs stay in `setState`/`Form` (design section 6).
- Navigation stays on go_router: `/` for the shell, `/deck/:deckId` pushed for Deck Editor. Back from Deck Editor returns to Library; Android back from another tab returns to Library.
- Material 3 only, no Cupertino. Palette `#FBF6EE` / `#FFFDF8` / `#9B5B32` / `#FAEBE2`. Fonts Newsreader, Inter, JetBrains Mono (already bundled).
- All data stays on the device. No server, no account, no network call, no analytics.
- Storage is drift (type-safe SQLite); only `Settings` (`ttsEnabled bool`, `reminderMinutes int`) uses `shared_preferences`.
- Rating enum `again, hard, good, easy`. CardSource enum `manual, slide, pdf, photo, shared`. Difficulty enum `easy, moderate, hard`. `ease` starts at 2.5. `mastery` is 0.0 to 1.0.
- `.mindstack` file is JSON: deck title plus a list of cards with `question`, `answer`, `source`. Scheduling fields are never exported.
- Every package added gets a README row (purpose, license). No secrets in git. `flutter analyze` must report no errors. Tag `phase-3` only when the submission is ready.
- Phase 2 promised: darken the orange "DAYS TO EXAM" pill text (2.7:1) and the inactive nav labels (4.1:1) to at least 4.5:1.

## Feature Scope and Target

Baseline = what the starter already does on sample data.

| ID | Feature | Baseline | Phase 3 plan | End state |
|----|---------|----------|--------------|-----------|
| F1 | Import + on-device OCR | placeholder buttons | out of scope, Phase 4 (risk: ML Kit + PDF rendering) | Not started |
| F2 | Review drafts, tick, save to deck | works on sample drafts | persistent drafts, draft edit, drafts fed by shared-deck import | **Implemented** |
| F3 | Courses with exam date + days to exam | works in memory | persisted, validated, contrast fix | **Implemented** |
| F4 | Decks + cards: browse, add, edit, delete | edit is a stub | persisted, edit card sheet, delete confirm | **Implemented** |
| F5 | Spaced-repetition review | works, queue built once at start | persisted cards and ReviewLog, live queue, session summary from log | **Implemented** |
| F6 | Quiz from cards | uses sample questions | generated from stored cards, misses logged as `Rating.again` | **Implemented** |
| F7 | Progress: streak, mastery, planner, weakest | streak is placeholder | real streak and weakest from ReviewLog; planner validation | In progress (stretch: Implemented) |
| F8 | Merge, share, import deck | merge works in memory | persisted merge, import `.mindstack` as drafts; share export is stretch | In progress (stretch: Implemented) |

Score: 5 Implemented = 62.5% (floor, above the 50% minimum). F7 at half credit = about 69%. F7 and F8 fully done = 87.5%, only if time allows. Do not start Task 9 (stretch) before Task 8 is merged.

## Review Focus

Inputs the spec implies but a happy-path test would miss. Each has a test in the owning task.

1. Fresh install vs. relaunch: sample data seeds exactly once; a second launch must not duplicate it (Task 1).
2. Deleting the last card in a deck, or merging a deck into itself or into an empty deck: counts and mastery must not divide by zero (Tasks 3, 6).
3. Review queue with zero due cards: shows "Session complete" empty state, not a blank screen (Task 4).
4. Quiz on a deck or library with fewer than 4 cards (cannot make 3 distractors): show the empty state, never crash (Task 5).
5. Importing a corrupt, empty or non-`.mindstack` file, and picker cancelled: Inbox error state with Retry, no crash, no partial drafts (Task 7).

## File Structure

```
lib/
  core/                          # clock.dart, ids.dart, logger.dart, dates.dart (imports nothing app-level)
  domain/
    enums.dart  failures.dart  scheduler.dart
    repositories.dart            # TransactionRunner + the four repository interfaces (Task 1)
    models/                      # course, deck, deck_stats, flashcard, draft_card, review_log, quiz_question
  data/
    database/                    # app_database.dart, tables.dart, converters.dart, app_database.g.dart (generated, committed)
    repositories/                # drift_{library,card,draft,review_log}_repository.dart
    drift_transaction_runner.dart  failure_mapping.dart  mappers.dart
    seed.dart                    # seeds sample_data.dart once (Task 1)
    sample_data.dart             # seed input only
    (Task 7 adds repositories/mindstack_file.dart: encode/decode .mindstack JSON)
  application/
    core_providers.dart          # clock, ids, logger, database, repositories, transactionRunner
    startup.dart                 # appStartupProvider
    library.dart cards.dart inbox.dart review.dart quiz.dart settings.dart tab.dart validation.dart
    (Task 6 adds stats.dart: streak, weakest, mastery by deck)
  presentation/
    screens/ widgets/            # existing screens + app_gate.dart; Tasks 3 and 7 add edit_card_sheet.dart, edit_draft_sheet.dart
    format.dart  save_feedback.dart
test/
  domain/ data/ application/ presentation/ support/   # unit, in-memory-database and widget tests per task
  fixtures/mindstack/            # sample .mindstack files (valid/ invalid/) + README, shared in git
docs/plan/phase3-plan.md         # this file
docs/phase3/                     # report material: screenshots, change log, contribution table (Task 10)
```

Note: decide in Task 0 whether `*.g.dart` is committed. Recommended: commit it so "clean checkout + `flutter pub get` + `flutter run`" works with no build_runner step (brief requires the app to start after only `flutter pub get`).

## Team Split (proposal, confirm in the group chat)

Each member needs verifiable commits/PRs, so every task below has one owner and goes through a PR with a second member as reviewer.

| Member | Area | Tasks |
|--------|------|-------|
| Firas Almashama | data layer, providers | 1, 3 |
| Jassim Alhumaid | Library, Inbox, shell, repo/README | 0, 7, 10 |
| Muhannad AlMelaifi | Review, Quiz, Stats screens, tests | 4, 5, 6 |
| Ibrahim Almuhanna | settings, sample data, share/import file format, report | 2, 8, 9 |

Task 0 owner also sets up the issue board: one GitHub issue per task, branch `feat/<task>`, PR required.

---

## Phase A: Foundation (do first, everything depends on it)

### Task 0: Baseline, branches and CI hygiene

**Files:** Modify `.gitignore`, `README.md` (status line only). Create GitHub issues, branch protection not required.

- [ ] **Step 1:** Run `flutter pub get && flutter analyze && flutter test` on a clean clone. Expected: no errors, 1 test passes. Fix anything that fails before other work starts.
- [ ] **Step 2:** Run `flutter run` on the Android emulator, click through all five tabs plus Deck Editor, note any defect as an issue (this is the "before" evidence for the report change log).
- [ ] **Step 3:** Create issues for Tasks 1 to 10, assign owners, label by phase. Agree commit style (`feat(scope): ...`) and that no one pushes straight to `main`.
- [ ] **Step 4:** Commit `docs: add Phase 3 plan`.

### Task 1: drift database, repositories, boot gate (F3, F4, F5 storage)

**Files:**
Files and steps below are the original plan; the Interfaces block describes what was built (see README for the layout).
- Modify: `pubspec.yaml` (add `drift`, `drift_flutter`, `path_provider`, dev `drift_dev`, `build_runner`; use `flutter pub add`)
- Create: `lib/data/app_database.dart`, `lib/data/seed.dart`, `lib/data/repositories/{library,card,draft,review_log}_repository.dart`, `lib/providers/boot_provider.dart`, `lib/widgets/app_gate.dart`
- Modify: `lib/main.dart`, `lib/app.dart`, `lib/providers/library_provider.dart`, `lib/providers/inbox_provider.dart`
- Test: `test/data/app_database_test.dart`, `test/data/seed_test.dart`

**Interfaces (as built; read `lib/domain/repositories.dart` and `lib/application/` for the source of truth):**
- Usage rule: read through the StreamProviders, write through the command classes, run multi-step writes through `transactionRunnerProvider`, and never hold a copy of database data in a notifier.
- Produces: `AppDatabase(QueryExecutor)` (`lib/data/database/app_database.dart`) with tables `Courses, Decks, Flashcards, DraftCards, ReviewLogs, Meta`. Only the composition root (`application/core_providers.dart`, `application/startup.dart`) and tests import `data/`.
- Produces: `abstract interface class TransactionRunner { Future<T> run<T>(Future<T> Function() action); }` (repository calls inside `action` join one atomic transaction).
- Produces: `abstract interface class LibraryRepository { Stream<List<Course>> watchCourses(); Stream<List<Deck>> watchDecks(); Future<Deck> deckById(String id); Future<void> insertCourse(Course course); Future<void> insertDeck(Deck deck); Future<void> deleteDeck(String id); }` (`deleteDeck` cascades to cards and review logs).
- Produces: `abstract interface class CardRepository { Stream<List<Flashcard>> watchAll(); Stream<List<Flashcard>> watchByDeck(String deckId); Stream<Map<String, DeckStats>> watchDeckStats(); Future<List<Flashcard>> due({required DateTime now, String? deckId}); Future<Flashcard> byId(String id); Future<void> insert(Flashcard card); Future<void> insertAll(List<Flashcard> cards); Future<void> update(Flashcard card); Future<void> delete(String id); Future<int> moveToDeck({required String fromDeckId, required String toDeckId}); }`
- Produces: `abstract interface class DraftRepository { Stream<List<DraftCard>> watchAll(); Future<List<DraftCard>> selected(); Future<void> insertAll(List<DraftCard> drafts); Future<void> toggleSelected(String id); Future<void> delete(Iterable<String> ids); Future<void> clear(); }`
- Produces: `abstract interface class ReviewLogRepository { Stream<List<ReviewLog>> watchAll(); Future<void> insert(ReviewLog log); }`
- No upserts: `insert*` fails with `Conflict` on a duplicate id; `update` and `delete` throw `NotFound` for a missing row. Repositories throw only `AppFailure` (`lib/domain/failures.dart`): sealed `NotFound(entity, id)`, `Conflict(ConflictKind.duplicateId | duplicateTitle)`, `InvalidInput(field, reason)`, `StorageFailure(cause, stack)`, each with a plain-language `userMessage`.
- Produces (`application/core_providers.dart`): `clockProvider`, `idGeneratorProvider`, `loggerProvider`, `databaseProvider`, `seedDataProvider`, `sampleQuizProvider`, `libraryRepositoryProvider`, `cardRepositoryProvider`, `draftRepositoryProvider`, `reviewLogRepositoryProvider`, `transactionRunnerProvider` (all overridable in tests).
- Produces (read side): `coursesProvider` (`StreamProvider<List<Course>>`), `decksProvider` (`StreamProvider<List<Deck>>`), `deckProvider(id)` (`AsyncValue<Deck?>`, null data when missing), `allCardsProvider` (`StreamProvider<List<Flashcard>>`), `deckCardsProvider(deckId)`, `deckStatsProvider` (`StreamProvider<Map<String, DeckStats>>`), `draftsProvider` (`StreamProvider<List<DraftCard>>`), `ocrProgressProvider` (`StateProvider<double?>`).
- Produces (write side, validated; throw `InvalidInput`, `NotFound`, `Conflict` or `StorageFailure` as documented on each method):
  - `libraryCommandsProvider` -> `LibraryCommands { Future<String> createCourse({required String title, required DateTime examDate}); Future<String> createDeck({required String courseId, required String title}); Future<void> deleteDeck(String id); Future<int> mergeDecks({required String fromId, required String toId}); }` (`mergeDecks` runs in one transaction).
  - `cardCommandsProvider` -> `CardCommands { Future<String> addCard({required String deckId, required String question, required String answer, CardSource source = CardSource.manual, String? sourceRef}); Future<void> deleteCard(String id); Future<Flashcard> rateCard(String id, Rating rating); }` (`rateCard` reads, applies `Sm2Scheduler`, and writes in one transaction). There is no card-edit command yet: Task 3 adds `updateCard` here, built on `CardRepository.byId` and `update`.
  - `inboxCommandsProvider` -> `InboxCommands { Future<void> toggle(String id); Future<void> clear(); Future<int> saveSelectedTo(String deckId); }` (`saveSelectedTo` inserts cards and deletes the drafts in one transaction).
- Produces: `reviewProvider` (`AsyncNotifierProvider<ReviewNotifier, ReviewState>`): `build()` snapshots the due card ids; `Future<void> rate(Rating rating)` (rethrows `AppFailure`, releases the saving flag), `void restart()`, `Future<void> startDeck(String deckId)`, `Future<void> startWeak({int count = 3})`, `void skip()`. `currentReviewCardProvider` reads the current card live. `ReviewNotifier` does not write review logs yet: Task 4 adds that (`ReviewLogRepository.insert`).
- Produces: `appStartupProvider` (`FutureProvider<void>`: opens the database, seeds once, fails only with `AppFailure`) and the `AppGate` widget (`presentation/widgets/app_gate.dart`): spinner while startup runs, then an error card with **Retry** (`ref.invalidate(databaseProvider)`, which closes and reopens the database and restarts startup), then the router child.

- [ ] **Step 1: Write failing tests** with an in-memory `AppDatabase(NativeDatabase.memory())`: `test('card round-trips every Flashcard field')`, `test('seed runs once: second call leaves 2 courses, 4 decks, 9 cards')`, `test('moveDeck moves all cards of from-deck')`, `test('deleteDeck leaves other decks untouched')`.
- [ ] **Step 2:** Run `flutter test test/data` → FAIL (types missing).
- [ ] **Step 3:** Implement `AppDatabase` and the four drift repository implementations. Keep the abstract interfaces so Phase 4 can swap the source. Seed guard: a `meta` row or `SharedPreferences` flag `seeded=true`; seed from `sample_data.dart` in a single transaction.
- [ ] **Step 4:** Implement `appStartupProvider`/`AppGate`; screens read the StreamProviders and write through the command classes (see Interfaces).
- [ ] **Step 5:** Run `dart run build_runner build`, `flutter test`, `flutter analyze` → PASS. Manual check: add a course, force-stop the app, relaunch, the course is still there.
- [ ] **Step 6:** Commit `feat(data): drift database, repositories and boot gate`. Add drift and shared_preferences rows to README packages table.

### Task 2: Settings with shared_preferences (supports F5 read-aloud toggle)

**Files:** Modify `lib/providers/settings_provider.dart`, `pubspec.yaml`. Test: `test/providers/settings_provider_test.dart`.

**Interfaces:** Produces `SettingsNotifier` with `setTts(bool)` and `setReminderMinutes(int)` that persist; `SettingsState{ttsEnabled, reminderMinutes}` unchanged.

- [ ] **Step 1:** Test `test('ttsEnabled survives a new ProviderContainer')` using `SharedPreferences.setMockInitialValues`.
- [ ] **Step 2:** Run it → FAIL. **Step 3:** Implement persistence (load in boot, write on set). **Step 4:** PASS. **Step 5:** Commit `feat(settings): persist settings`.

---

## Phase B: Core flows end to end (these deliver the 62.5%)

### Task 3: Library and Deck Editor on persistent data (F3, F4)

**Files:** Create `lib/widgets/edit_card_sheet.dart`, `lib/widgets/confirm_delete_dialog.dart`. Modify `lib/screens/deck_editor_screen.dart`, `lib/screens/library_screen.dart`, `lib/widgets/create_course_sheet.dart`, `lib/theme/app_theme.dart` (contrast). Test: `test/widgets/deck_editor_test.dart`, `test/providers/cards_provider_test.dart`.

**Interfaces:**
- Consumes: `CardRepository`, `allCardsProvider` / `deckCardsProvider`, `cardCommandsProvider` from Task 1.
- Produces: `CardCommands.updateCard({required String id, required String question, required String answer})` (edit question/answer, keeps scheduling fields; reads with `CardRepository.byId` and writes with `CardRepository.update` in one transaction); `showEditCardSheet(BuildContext, Flashcard)`; Delete asks for confirmation then shows an undo SnackBar.

- [ ] **Step 1: Failing tests:** `test('editing a card keeps intervalDays, ease and dueAt')`; `test('empty question shows "Enter a question" and does not save')` (validation messages already used by Add Card); `test('deleting the last card shows the empty state "No cards yet. Tap + Card to add one"')`; `test('deck mastery of an empty deck is 0, no exception')`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement edit sheet (reuse `add_card_sheet.dart` form widgets, do not copy the form), delete confirm + undo, Library empty state "No courses yet. Tap + Course to add one". **Step 4:** Darken the DAYS TO EXAM pill text and inactive nav label colors to ≥ 4.5:1 and note the measured ratio in the PR. **Step 5:** PASS, then manual: add, edit, delete a card, relaunch, changes persist, Library counts and mastery update without restart. **Step 6:** Commit.

**Vertical slice for the demo (flow 1):** Library → + Course (validation error, then valid) → + Deck → Deck Editor → + Card → card appears, Library count updates → relaunch → still there.

### Task 4: Review session on stored cards with ReviewLog (F5)

**Files:** Modify `lib/providers/review_provider.dart`, `lib/screens/review_screen.dart`, `lib/providers/library_provider.dart` (rate writes log). Test: `test/providers/review_provider_test.dart`, `test/widgets/review_screen_test.dart`.

**Interfaces:**
- Consumes: `ReviewLogRepository.insert`, `CardRepository.update` (via `CardCommands.rateCard`).
- Produces: `ReviewNotifier.build()` snapshots the cards with `dueAt <= now`; `ReviewNotifier.startDeck(String deckId)` (Study from Deck Editor) and `ReviewNotifier.startWeak({int count = 3})` (Stats "Drill" and Quiz "Review weak cards") already exist from Task 1. This task extends `rate(Rating)` / `CardCommands.rateCard` to also append a `ReviewLog(elapsedMs)` in the same transaction via `ReviewLogRepository.insert`; queue rebuilds when the Review tab opens (fixes the known "queue built once at start" bug).

- [ ] **Step 1: Failing tests:** `test('rating good persists new intervalDays and writes one ReviewLog')`; `test('a card added after launch appears in the next queue')`; `test('empty queue shows "Session complete" empty state')` (Review Focus 3); `test('Study from Deck Editor filters queue to that deck')`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. Session summary (cards reviewed, elapsed, pace, next due) is computed from this session's logs, not hard-coded. **Step 4:** PASS + manual relaunch check: a rated card keeps its new due date. **Step 5:** Commit.

### Task 5: Quiz generated from stored cards (F6)

**Files:** Modify `lib/providers/quiz_provider.dart`, `lib/screens/quiz_screen.dart`. Create `lib/utils/quiz_builder.dart`. Test: `test/utils/quiz_builder_test.dart`, `test/widgets/quiz_screen_test.dart`.

**Interfaces:**
- Produces: `List<QuizQuestion> buildQuiz(List<Flashcard> cards, {int count = 5, Random? random})`: correct answer is the card's answer, plus three answers from other cards (same deck first), `correctIndex` shuffled, `explanation` = the card's answer text, `points` 1 to 2 by `Difficulty` (from card mastery). Returns `[]` if fewer than 4 cards.
- Consumes: `ReviewLogRepository.insert` (a missed answer logs `Rating.again` for that card).

- [ ] **Step 1: Failing tests:** `test('buildQuiz returns 5 questions with 4 distinct options each')`; `test('correctIndex points at the card answer')` (seeded Random); `test('fewer than 4 cards returns empty list')`; `test('missed answer writes a Rating.again log')`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement builder and wire `QuizNotifier`; Quiz tab shows the empty state "Add at least 4 cards to start a quiz" when `buildQuiz` returns empty (Review Focus 4). **Step 4:** PASS. **Step 5:** Results screen "Review weak cards" calls `ReviewNotifier.startWeak()` and switches to the Review tab. **Step 6:** Commit.

### Task 6: Stats from real history (F7, target In progress, stretch Implemented)

**Files:** Create `lib/providers/stats_provider.dart`. Modify `lib/screens/stats_screen.dart`. Test: `test/providers/stats_provider_test.dart`.

**Interfaces:**
- Produces: `final streakProvider = Provider<StreakInfo>` (`current int`, `best int`, `days List<bool>` for the last 28 days, built from distinct `reviewedAt` dates); `final weakestCardsProvider = Provider<List<Flashcard>>` (lowest mastery first, max 3, cards with at least one log); `masteryByDeckProvider` for the fl_chart bars.

- [ ] **Step 1: Failing tests:** `test('3 consecutive review days give current streak 3')`; `test('no reviews gives streak 0 and an empty weakest list')`; `test('gap day resets current but not best')`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement providers, replace placeholder streak, keep the planner in `setState`; planner shows an inline message when the date is missing/past or the total is not a positive integer (design: "Inline message in the planner"). Empty state "No reviews yet" for streak and weakest. "Drill 3 weak cards now" calls `ReviewNotifier.startWeak()`. **Step 4:** PASS. **Step 5:** Commit.

---

## Phase C: Draft pipeline, sharing, and wrap-up

### Task 7: Draft persistence, draft edit, import shared deck (F2, part of F8)

**Files:** Create `lib/data/repositories/mindstack_file.dart`, `lib/widgets/edit_draft_sheet.dart`. Modify `lib/application/inbox.dart`, `lib/presentation/screens/inbox_screen.dart`, `pubspec.yaml` (`file_picker`). Test: `test/data/mindstack_file_test.dart`, `test/providers/inbox_provider_test.dart`, `test/widgets/inbox_screen_test.dart`.

**Interfaces:**
- Produces: `class MindstackFile { final String deckTitle; final List<MindstackCard> cards; }`, `MindstackFile.parse(String json)` (throws `FormatException` with a user-readable message on bad input), `String encode()`.
- Produces: `InboxCommands.importShared() -> Future<void>` (added to `inboxCommandsProvider`): opens file_picker for `.mindstack`, parses, inserts drafts with `source = CardSource.shared`; state exposes `InboxStatus { idle, loading, error(message) }`.
- Produces: `InboxCommands.updateDraft(String id, {String? question, String? answer})`, backed by a new `DraftRepository.update(DraftCard)` that throws `NotFound` for a missing draft.

- [ ] **Step 1: Failing tests:** `test('parse round-trips encode')`; `test('parse rejects empty string, non-JSON and JSON without cards')` (Review Focus 5); `test('picker cancelled leaves drafts unchanged and status idle')`; `test('draft with empty question cannot be saved in the edit sheet')`; `test('saveSelectedTo removes drafts from DB and adds cards')`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. Loading state shows the existing skeleton cards; error state shows "This file couldn't be read" with **Retry import** and **Choose another file**. Remove the "Editing drafts arrives in Phase 3" snack. **Step 4:** PASS + manual: hand-write a `.mindstack` file, push to the emulator, import, edit one draft, untick one, Save selected to a deck, cards appear in Deck Editor, relaunch keeps them. **Step 5:** Commit.

**Vertical slice for the demo (flow 2, the headline flow):** Inbox → Import a shared deck → drafts appear → Edit one → Save selected → Choose deck → toast → Deck Editor shows the cards → Review them.

### Task 8: Merge persisted (F8) and navigation audit

**Files:** Modify `lib/screens/deck_editor_screen.dart` (merge calls `LibraryCommands.mergeDecks`, which already moves the cards with `CardRepository.moveToDeck` and deletes the source deck via `LibraryRepository.deleteDeck` in one transaction; this task adds the tests and the audit). Test: `test/widgets/navigation_test.dart`, `test/providers/merge_test.dart`.

- [ ] **Step 1: Failing tests:** `test('merge moves cards and removes source deck, persisted')`; `test('merge into an empty deck works')`; `test('every tab and /deck/:id is reachable and back returns to Library')`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement; fix the real nav gaps the audit finds. **Step 4:** PASS. **Step 5:** Commit.

### Task 9 (stretch, only after Task 8 merged): Share export, read-aloud

**Files:** Modify `lib/screens/deck_editor_screen.dart`, `lib/screens/review_screen.dart`, `pubspec.yaml` (`share_plus`, `flutter_tts`). Test: `test/data/mindstack_file_test.dart` (encode only; share sheet is checked by hand).

- [ ] **Step 1:** Test `test('encode omits intervalDays, ease, dueAt, repetitions')`.
- [ ] **Step 2:** Implement ⋮ → Share deck: write `<deck>.mindstack` to a temp dir, `Share.shareXFiles`. **Step 3:** TTS toggle speaks the question when a card is shown and the answer when flipped; off by default; stop on dispose. **Step 4:** Commit. This moves F8 to Implemented and F5 gets its read-aloud behavior.

### Task 10: Hardening, README, report, tag

**Files:** Modify `README.md`; create `docs/phase3/{change-log.md,feature-checklist.md,contributions.md}` and screenshots; run the checklist below.

- [ ] **Step 1: Runtime-state audit:** for every async flow (boot, import, review start, quiz build) confirm loading, empty, success and failure are visible. Screenshot each (Inbox loading, Inbox error, Library empty, Deck empty, Review complete, Quiz empty, Stats empty).
- [ ] **Step 2:** `flutter analyze` → no errors; `flutter test` → all pass; on a **clean clone** `flutter pub get && flutter run` starts without build_runner.
- [ ] **Step 3:** README: purpose, setup/run, implemented Phase 3 features, packages with purpose and license (drift MIT, drift_flutter MIT, path_provider BSD-3, shared_preferences BSD-3, file_picker MIT, share_plus BSD-3, flutter_tts MIT), data source (drift/SQLite, seeded sample data), known issues, AI-use disclosure that matches what the team really used.
- [ ] **Step 4:** Report `GroupXX_Phase3_Prototype.pdf` in the required order (cover, Phase 2 changes, feature table with percentage, working flow, screenshots + navigation note, state and data, quality and known issues, contribution record per member with commits/PRs, testing steps pointing the instructor to `test/fixtures/mindstack/valid/01_flutter_widgets.mindstack` as the sample import file). Phase 2 changes to list: drift added, boot gate, import-as-draft feeds F2, OCR moved to Phase 4.
- [ ] **Step 5:** Check `git shortlog -sn` shows all four members with meaningful commits; confirm no secrets (`git grep -iE "api[_-]?key|secret|token"`).
- [ ] **Step 6:** Merge to `main`, then `git tag phase-3 && git push origin main --tags`. Verify the repo link opens for the instructor.

---

## Suggested Order and Sizing

| Order | Task | Depends on | Size | Parallel with |
|-------|------|-----------|------|---------------|
| 1 | 0 Baseline | none | S | |
| 2 | 1 Database + boot | 0 | L (critical path, finish first) | 2 |
| 2 | 2 Settings | 0 | S | 1 |
| 3 | 3 Library/Deck Editor | 1 | M | 4, 5, 6, 7 |
| 3 | 4 Review | 1 | M | 3, 5, 6, 7 |
| 3 | 5 Quiz | 1, 4 (start API) | M | 3, 6, 7 |
| 3 | 6 Stats | 1, 4 | M | 3, 5, 7 |
| 3 | 7 Drafts + import | 1 | L | 3 to 6 |
| 4 | 8 Merge + nav audit | 3 | S | |
| 5 | 9 Stretch | 8 | M | |
| 6 | 10 Hardening + submit | all | M | start README early |

Cut line if time runs out: drop 9, then 6's polish, then 8's extras. Never drop 1, 3, 4, 5, 7: they are the 5 Implemented features.

## Self-Review Notes

- Spec coverage: F2 to F8 each map to a task; F1 explicitly deferred with the reason. Brief items map as: nav (Task 8), forms (3, 7), state (all), data source (1), runtime states (1, 4, 5, 6, 7, 10), organization/teamwork (team split + 0), README/report/tag (10).
- Open decisions for the group: (1) confirm F1 stays in Phase 4, (2) commit `*.g.dart` or not (recommended yes), (3) confirm the owner split, (4) the demo device is the Android emulator.
