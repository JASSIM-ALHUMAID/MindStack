import 'package:drift/drift.dart';

import '../../domain/failures.dart';
import '../../domain/models/review_log.dart';
import '../../domain/repositories.dart';
import '../database/app_database.dart';
import '../failure_mapping.dart';
import '../mappers.dart';

/// [ReviewLogRepository] backed by drift. Logs are listed in insertion order.
final class DriftReviewLogRepository implements ReviewLogRepository {
  /// Creates a repository reading and writing [_db].
  const DriftReviewLogRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ReviewLog>> watchAll() {
    final query = _db.select(_db.reviewLogs)
      ..orderBy([(t) => OrderingTerm.asc(t.rowId)]);
    return guardStream(
      query.watch().map((rows) => [for (final r in rows) r.toModel()]),
    );
  }

  @override
  Future<void> insert(ReviewLog log) => guard(
    () => _db.into(_db.reviewLogs).insert(log.toCompanion()),
    onForeignKey: () => NotFound(entity: 'card', id: log.cardId),
  );
}
