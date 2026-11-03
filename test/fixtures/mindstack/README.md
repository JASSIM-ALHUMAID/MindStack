# `.mindstack` fixtures

Sample deck files used by the parser tests and for manual testing of **Inbox > Import a shared deck**.

## Format

```json
{ "deckTitle": "string",
  "cards": [ { "question": "string", "answer": "string", "source": "manual|slide|pdf|photo|shared" } ] }
```

Scheduling fields (interval, ease, dueAt) are never in the file.

## valid/ (import as draft cards)

| File | Tests |
|------|-------|
| 01_flutter_widgets | normal deck, 5 cards, mixed sources |
| 02_dart_fundamentals | 6 cards |
| 03_riverpod_state | 4 cards, exactly enough to build quiz distractors |
| 04_single_card | smallest deck, 1 draft |
| 05_unicode_and_long_text | Arabic, emoji, escapes, newline/tab, very long answer |
| 06_ten_cards_quiz_ready | 10 cards, enough for a full 5-question quiz |

## invalid/ (must fail with "This file couldn't be read", no drafts added)

bad_01 not JSON, bad_02 empty file, bad_03 no `cards` key, bad_04 empty `cards`, bad_05 card missing `answer`, bad_06 truncated JSON.

## Manual testing on the emulator

```bash
adb push test/fixtures/mindstack/valid/. /sdcard/Download/
```

Then open the Inbox tab, tap **Import a shared deck**, and pick a file from Downloads.

## In tests

```dart
final json = File('test/fixtures/mindstack/valid/01_flutter_widgets.mindstack').readAsStringSync();
```

Flutter tests run with the project root as the working directory, so this relative path works.
