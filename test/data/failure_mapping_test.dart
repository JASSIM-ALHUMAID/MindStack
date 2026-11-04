import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/data/database/app_database.dart';
import 'package:mindstack/data/drift_transaction_runner.dart';
import 'package:mindstack/data/failure_mapping.dart';
import 'package:mindstack/data/mappers.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/models/flashcard.dart';

import '../support/test_database.dart';

final _course = Course(
  id: 'c1',
  title: 'Mobile',
  examDate: DateTime(2026, 12, 1),
);
const _deck = Deck(id: 'd1', courseId: 'c1', title: 'Flutter');

Future<AppDatabase> _open() async {
  final db = openTestDatabase();
  addTearDown(db.close);
  await db.into(db.courses).insert(_course.toCompanion());
  await db.into(db.decks).insert(_deck.toCompanion());
  return db;
}

void main() {
  test('duplicate primary key maps to Conflict(duplicateId)', () async {
    final db = await _open();
    await expectLater(
      guard(() => db.into(db.courses).insert(_course.toCompanion())),
      throwsA(
        isA<Conflict>().having((c) => c.kind, 'kind', ConflictKind.duplicateId),
      ),
    );
  });

  test('duplicate title maps to Conflict(duplicateTitle)', () async {
    final db = await _open();
    await expectLater(
      guard(
        () => db
            .into(db.decks)
            .insert(
              const Deck(
                id: 'd2',
                courseId: 'c1',
                title: 'FLUTTER',
              ).toCompanion(),
            ),
      ),
      throwsA(
        isA<Conflict>().having(
          (c) => c.kind,
          'kind',
          ConflictKind.duplicateTitle,
        ),
      ),
    );
  });

  test('foreign key violation uses the onForeignKey result', () async {
    final db = await _open();
    const missing = NotFound(entity: 'deck', id: 'nope');
    await expectLater(
      guard(
        () => db
            .into(db.flashcards)
            .insert(
              Flashcard(
                id: 'k1',
                deckId: 'nope',
                question: 'Q',
                answer: 'A',
                dueAt: DateTime(2026, 11, 4),
              ).toCompanion(),
            ),
        onForeignKey: () => missing,
      ),
      throwsA(same(missing)),
    );
  });

  test('foreign key violation defaults to a generic NotFound', () async {
    final db = await _open();
    await expectLater(
      guard(
        () => db
            .into(db.decks)
            .insert(
              const Deck(id: 'd9', courseId: 'nope', title: 'X').toCompanion(),
            ),
      ),
      throwsA(
        isA<NotFound>()
            .having((e) => e.entity, 'entity', 'related item')
            .having((e) => e.id, 'id', ''),
      ),
    );
  });

  test('CHECK violation maps to InvalidInput', () async {
    final db = await _open();
    await expectLater(
      guard(
        () => db
            .into(db.decks)
            .insert(
              const Deck(id: 'd2', courseId: 'c1', title: ' ').toCompanion(),
            ),
      ),
      throwsA(
        isA<InvalidInput>()
            .having((e) => e.field, 'field', 'text')
            .having(
              (e) => e.reason,
              'reason',
              'Some required text is missing.',
            ),
      ),
    );
  });

  test('a duplicate key through a drift isolate maps to Conflict', () async {
    // Over an isolate connection the SqliteException arrives wrapped in a
    // DriftRemoteException, exactly as on a device.
    final isolate = await DriftIsolate.spawn(NativeDatabase.memory);
    final db = AppDatabase(await isolate.connect(singleClientMode: true));
    addTearDown(db.close);
    await db.into(db.courses).insert(_course.toCompanion());

    Object? raw;
    try {
      await db.into(db.courses).insert(_course.toCompanion());
    } on Object catch (e) {
      raw = e;
    }
    expect(raw, isA<DriftRemoteException>());

    await expectLater(
      guard(() => db.into(db.courses).insert(_course.toCompanion())),
      throwsA(
        isA<Conflict>().having((c) => c.kind, 'kind', ConflictKind.duplicateId),
      ),
    );
  });

  test('unknown errors become StorageFailure with the cause', () async {
    final cause = StateError('boom');
    await expectLater(
      guard<void>(() => Future<void>.error(cause)),
      throwsA(
        isA<StorageFailure>().having((f) => f.cause, 'cause', same(cause)),
      ),
    );
  });

  test('AppFailure passes through unchanged', () async {
    const failure = NotFound(entity: 'deck', id: 'x');
    await expectLater(
      guard<void>(() => Future<void>.error(failure)),
      throwsA(same(failure)),
    );
  });

  test('guardStream maps errors emitted by the stream', () async {
    final stream = guardStream<int>(
      Stream.fromFutures([Future.value(1), Future<int>.error(StateError('x'))]),
    );
    expect(stream, emitsInOrder([1, emitsError(isA<StorageFailure>())]));
  });

  test('DriftTransactionRunner commits and maps failures', () async {
    final db = await _open();
    final runner = DriftTransactionRunner(db);

    await runner.run(
      () => db
          .into(db.decks)
          .insert(
            const Deck(id: 'd2', courseId: 'c1', title: 'Dart').toCompanion(),
          ),
    );
    await expectLater(
      runner.run(() async {
        await db
            .into(db.decks)
            .insert(
              const Deck(
                id: 'd3',
                courseId: 'c1',
                title: 'Riverpod',
              ).toCompanion(),
            );
        await db.into(db.decks).insert(_deck.toCompanion());
      }),
      throwsA(isA<Conflict>()),
    );
    final titles = (await db.select(db.decks).get()).map((d) => d.title);
    expect(titles, unorderedEquals(['Flutter', 'Dart']));
  });

  test('guardStream passes an AppFailure through unchanged', () async {
    const failure = NotFound(entity: 'deck', id: 'd9');
    final stream = guardStream<int>(Stream<int>.error(failure));
    await expectLater(stream, emitsError(same(failure)));
  });
}
