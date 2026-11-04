import 'package:drift/drift.dart';

import '../../domain/failures.dart';
import '../../domain/models/draft_card.dart';
import '../../domain/repositories.dart';
import '../database/app_database.dart';
import '../failure_mapping.dart';
import '../mappers.dart';

/// [DraftRepository] backed by drift. Drafts are listed in insertion order.
final class DriftDraftRepository implements DraftRepository {
  /// Creates a repository reading and writing [_db].
  const DriftDraftRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$DraftCardsTable, DraftCardRow> _byInsertion() =>
      _db.select(_db.draftCards)..orderBy([(t) => OrderingTerm.asc(t.rowId)]);

  @override
  Stream<List<DraftCard>> watchAll() => guardStream(
    _byInsertion().watch().map((rows) => [for (final r in rows) r.toModel()]),
  );

  @override
  Future<List<DraftCard>> selected() => guard(() async {
    final query = _byInsertion()..where((t) => t.selected.equals(true));
    return [for (final r in await query.get()) r.toModel()];
  });

  @override
  Future<void> insertAll(List<DraftCard> drafts) => guard(
    () => _db.transaction(
      () => _db.batch(
        (b) => b.insertAll(_db.draftCards, [
          for (final d in drafts) d.toCompanion(),
        ]),
      ),
    ),
  );

  @override
  Future<void> toggleSelected(String id) => guard(() async {
    // One statement, so concurrent toggles cannot read-modify-write.
    final changed = await _db.customUpdate(
      'UPDATE draft_cards SET selected = NOT selected WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {_db.draftCards},
    );
    if (changed == 0) throw NotFound(entity: 'draft', id: id);
  });

  @override
  Future<void> delete(Iterable<String> ids) => guard(() async {
    await (_db.delete(_db.draftCards)..where((t) => t.id.isIn(ids))).go();
  });

  @override
  Future<void> clear() => guard(() async {
    await _db.delete(_db.draftCards).go();
  });
}
