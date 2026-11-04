import 'package:drift/drift.dart';

import '../../domain/failures.dart';
import '../../domain/models/deck_stats.dart';
import '../../domain/models/flashcard.dart';
import '../../domain/repositories.dart';
import '../database/app_database.dart';
import '../failure_mapping.dart';
import '../mappers.dart';

/// [CardRepository] backed by drift. Cards are listed in insertion order.
final class DriftCardRepository implements CardRepository {
  /// Creates a repository reading and writing [_db].
  const DriftCardRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$FlashcardsTable, FlashcardRow> _byInsertion() =>
      _db.select(_db.flashcards)..orderBy([(t) => OrderingTerm.asc(t.rowId)]);

  @override
  Stream<List<Flashcard>> watchAll() => guardStream(
    _byInsertion().watch().map((rows) => [for (final r in rows) r.toModel()]),
  );

  @override
  Stream<List<Flashcard>> watchByDeck(String deckId) {
    final query = _byInsertion()..where((t) => t.deckId.equals(deckId));
    return guardStream(
      query.watch().map((rows) => [for (final r in rows) r.toModel()]),
    );
  }

  @override
  Stream<Map<String, DeckStats>> watchDeckStats() {
    final count = _db.flashcards.id.count();
    final mastery = coalesce([
      _db.flashcards.mastery.avg(),
      const Constant(0.0),
    ]);
    final query =
        _db.select(_db.decks).join([
            leftOuterJoin(
              _db.flashcards,
              _db.flashcards.deckId.equalsExp(_db.decks.id),
            ),
          ])
          ..addColumns([count, mastery])
          ..groupBy([_db.decks.id]);
    return guardStream(
      query.watch().map((rows) {
        final stats = <String, DeckStats>{};
        for (final row in rows) {
          final deckId = row.read(_db.decks.id)!;
          stats[deckId] = DeckStats(
            deckId: deckId,
            cardCount: row.read(count)!,
            mastery: row.read(mastery)!,
          );
        }
        return stats;
      }),
    );
  }

  @override
  Future<List<Flashcard>> due({required DateTime now, String? deckId}) =>
      guard(() async {
        final query = _byInsertion()
          ..where((t) => t.dueAt.isSmallerOrEqualValue(now.toUtc()));
        if (deckId != null) query.where((t) => t.deckId.equals(deckId));
        return [for (final r in await query.get()) r.toModel()];
      });

  @override
  Future<Flashcard> byId(String id) => guard(() async {
    final row = await (_db.select(
      _db.flashcards,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) throw NotFound(entity: 'card', id: id);
    return row.toModel();
  });

  @override
  Future<void> insert(Flashcard card) => guard(
    () => _db.into(_db.flashcards).insert(card.toCompanion()),
    onForeignKey: () => NotFound(entity: 'deck', id: card.deckId),
  );

  @override
  Future<void> insertAll(List<Flashcard> cards) => guard(
    () => _db.transaction(
      () => _db.batch(
        (b) => b.insertAll(_db.flashcards, [
          for (final c in cards) c.toCompanion(),
        ]),
      ),
    ),
    // The failing row is not reported by SQLite; name the deck when the
    // batch targets exactly one, otherwise leave the id empty.
    onForeignKey: () {
      final deckIds = {for (final c in cards) c.deckId};
      return NotFound(
        entity: 'deck',
        id: deckIds.length == 1 ? deckIds.single : '',
      );
    },
  );

  @override
  Future<void> update(Flashcard card) => guard(() async {
    final changed = await (_db.update(
      _db.flashcards,
    )..where((t) => t.id.equals(card.id))).write(card.toCompanion());
    if (changed == 0) throw NotFound(entity: 'card', id: card.id);
  }, onForeignKey: () => NotFound(entity: 'deck', id: card.deckId));

  @override
  Future<void> delete(String id) => guard(() async {
    final removed = await (_db.delete(
      _db.flashcards,
    )..where((t) => t.id.equals(id))).go();
    if (removed == 0) throw NotFound(entity: 'card', id: id);
  });

  @override
  Future<int> moveToDeck({
    required String fromDeckId,
    required String toDeckId,
  }) => guard(
    () =>
        (_db.update(_db.flashcards)..where((t) => t.deckId.equals(fromDeckId)))
            .write(FlashcardsCompanion(deckId: Value(toDeckId))),
    onForeignKey: () => NotFound(entity: 'deck', id: toDeckId),
  );
}
