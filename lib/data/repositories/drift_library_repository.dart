import 'package:drift/drift.dart';

import '../../domain/failures.dart';
import '../../domain/models/course.dart';
import '../../domain/models/deck.dart';
import '../../domain/repositories.dart';
import '../database/app_database.dart';
import '../failure_mapping.dart';
import '../mappers.dart';

/// [LibraryRepository] backed by drift.
final class DriftLibraryRepository implements LibraryRepository {
  /// Creates a repository reading and writing [_db].
  const DriftLibraryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Course>> watchCourses() {
    final query = _db.select(_db.courses)
      ..orderBy([
        (t) => OrderingTerm.asc(t.examDate),
        (t) => OrderingTerm.asc(t.title),
      ]);
    return guardStream(
      query.watch().map((rows) => [for (final r in rows) r.toModel()]),
    );
  }

  @override
  Stream<List<Deck>> watchDecks() {
    final query = _db.select(_db.decks)
      ..orderBy([
        // Titles are unique case-insensitively, so sort the same way.
        (t) => OrderingTerm.asc(t.title.collate(Collate.noCase)),
      ]);
    return guardStream(
      query.watch().map((rows) => [for (final r in rows) r.toModel()]),
    );
  }

  @override
  Future<Deck> deckById(String id) => guard(() async {
    final row = await (_db.select(
      _db.decks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) throw NotFound(entity: 'deck', id: id);
    return row.toModel();
  });

  @override
  Future<void> insertCourse(Course course) =>
      guard(() => _db.into(_db.courses).insert(course.toCompanion()));

  @override
  Future<void> insertDeck(Deck deck) => guard(
    () => _db.into(_db.decks).insert(deck.toCompanion()),
    onForeignKey: () => NotFound(entity: 'course', id: deck.courseId),
  );

  @override
  Future<void> deleteDeck(String id) => guard(() async {
    final removed = await (_db.delete(
      _db.decks,
    )..where((t) => t.id.equals(id))).go();
    if (removed == 0) throw NotFound(entity: 'deck', id: id);
  });
}
