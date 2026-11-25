import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:mindstack/data/repositories/drift_draft_repository.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/models/draft_card.dart';

// draft_cards exactly as schema v1 (the phase-3 tag) created it.
const _v1DraftCards =
    'CREATE TABLE "draft_cards" ("id" TEXT NOT NULL, "source" TEXT NOT NULL, '
    '"source_ref" TEXT NOT NULL, "question" TEXT NOT NULL, '
    '"answer" TEXT NOT NULL, "selected" INTEGER NOT NULL DEFAULT 1 '
    'CHECK ("selected" IN (0, 1)), PRIMARY KEY ("id"))';

/// Opens [AppDatabase] on a v1 file holding drafts [ids], inserted in order.
AppDatabase _openV1(List<String> ids) {
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(_v1DraftCards);
          for (final id in ids) {
            raw.execute(
              'INSERT INTO draft_cards (id, source, source_ref, question, '
              "answer, selected) VALUES (?, 'slide', 'Page 1', ?, ?, 1)",
              [id, 'Q $id', 'A $id'],
            );
          }
          raw.execute('PRAGMA user_version = 1');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  return db;
}

void main() {
  test('upgrading v1 keeps every draft in its order', () async {
    final db = _openV1(['c', 'a', 'b']);
    final drafts = await DriftDraftRepository(db).watchAll().first;

    expect([for (final d in drafts) d.id], ['c', 'a', 'b']);
    expect([for (final d in drafts) d.position], [1, 2, 3]);
    expect(drafts.first.question, 'Q c');
  });

  test('after the upgrade the version is 2 and new drafts append', () async {
    final db = _openV1(['a']);
    final repo = DriftDraftRepository(db);

    await repo.insertAll([
      const DraftCard(
        id: 'n',
        source: CardSource.shared,
        sourceRef: 'Deck',
        question: 'Q n',
        answer: 'A n',
      ),
    ]);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 2);
    expect([for (final d in await repo.watchAll().first) d.id], ['a', 'n']);
  });
}
