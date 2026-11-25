import 'package:drift/drift.dart';

// The generated part references the enums and converter used by the tables.
// ignore_for_file: unused_import
import '../../domain/enums.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The MindStack SQLite database (schema v2).
///
/// Integrity is enforced by the store: foreign keys with cascading deletes,
/// CHECK constraints, a case-insensitive unique deck title per course and
/// indexes for the hot queries. Construct it with a platform executor.
@DriftDatabase(
  tables: [Courses, Decks, Flashcards, DraftCards, ReviewLogs, Meta],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database on the executor [e]. Use `driftDatabase` in the app
  /// and `NativeDatabase.memory()` in tests.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2 adds draft_cards.position. SQLite cannot add a NOT NULL column
        // without a default, so the table is rebuilt; old drafts keep their
        // order because position is filled from rowid.
        await m.alterTable(
          TableMigration(
            draftCards,
            columnTransformer: {draftCards.position: draftCards.rowId},
            newColumns: [draftCards.position],
          ),
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Forces the connection open (running [migration]) so startup can surface
  /// a broken database before any screen reads from it.
  Future<void> ensureOpen() async {
    await customSelect('SELECT 1').get();
  }
}
