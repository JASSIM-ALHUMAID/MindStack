import '../domain/models/course.dart';
import '../domain/models/deck.dart';
import '../domain/models/draft_card.dart';
import '../domain/models/flashcard.dart';
import 'database/app_database.dart';
import 'failure_mapping.dart';
import 'mappers.dart';

const _seededKey = 'seeded';

/// The rows stored by [seedIfNeeded].
class SeedData {
  /// Creates a seed set. Parents must precede children by reference only;
  /// insertion order is handled by [seedIfNeeded].
  const SeedData({
    required this.courses,
    required this.decks,
    required this.cards,
    required this.drafts,
  });

  final List<Course> courses;
  final List<Deck> decks;
  final List<Flashcard> cards;
  final List<DraftCard> drafts;
}

/// Stores [data] the first time it runs on a database and never again.
///
/// Everything, including the `seeded` flag in `meta`, is written in one
/// transaction: a failure leaves no rows and no flag. The flag outlives the
/// rows, so a user who deletes everything is not given the samples back.
/// Throws only `AppFailure`.
Future<void> seedIfNeeded(AppDatabase db, SeedData data) => guard(
  () => db.transaction(() async {
    final flag = await (db.select(
      db.meta,
    )..where((t) => t.key.equals(_seededKey))).getSingleOrNull();
    if (flag != null) return;
    await db.batch((b) {
      b.insertAll(db.courses, [for (final c in data.courses) c.toCompanion()]);
      b.insertAll(db.decks, [for (final d in data.decks) d.toCompanion()]);
      b.insertAll(db.flashcards, [for (final c in data.cards) c.toCompanion()]);
      b.insertAll(db.draftCards, [
        for (final d in data.drafts) d.toCompanion(),
      ]);
    });
    await db
        .into(db.meta)
        .insert(MetaCompanion.insert(key: _seededKey, value: 'true'));
  }),
);
