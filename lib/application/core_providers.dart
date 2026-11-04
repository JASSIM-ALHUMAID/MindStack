import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../core/logger.dart';
import '../data/database/app_database.dart';
import '../data/drift_transaction_runner.dart';
import '../data/repositories/drift_card_repository.dart';
import '../data/repositories/drift_draft_repository.dart';
import '../data/repositories/drift_library_repository.dart';
import '../data/repositories/drift_review_log_repository.dart';
import '../data/sample_data.dart';
import '../data/seed.dart';
import '../domain/models/quiz_question.dart';
import '../domain/repositories.dart';

/// The time source. Override in tests with a fixed clock.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The id source. Override in tests with a sequential generator.
final idGeneratorProvider = Provider<IdGenerator>((ref) => UuidGenerator());

/// The error log. Override in tests to record calls.
final loggerProvider = Provider<AppLogger>((ref) => const FlutterAppLogger());

/// The app database. Invalidating it closes the current database and opens a
/// fresh one, which is how startup Retry recovers from a failed open.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'mindstack'));
  // Provider disposal is synchronous, so the asynchronous close is started
  // here and deliberately not awaited.
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

/// The rows stored the first time the app runs on an empty database.
final seedDataProvider = Provider<SeedData>(
  (ref) => buildSampleData(ref.watch(clockProvider).now()),
);

/// The questions the quiz tab asks. Replaced by generated quizzes later.
final sampleQuizProvider = Provider<List<QuizQuestion>>((ref) => sampleQuiz);

/// Courses and decks.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => DriftLibraryRepository(ref.watch(databaseProvider)),
);

/// Flashcards.
final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => DriftCardRepository(ref.watch(databaseProvider)),
);

/// OCR drafts.
final draftRepositoryProvider = Provider<DraftRepository>(
  (ref) => DriftDraftRepository(ref.watch(databaseProvider)),
);

/// The review log.
final reviewLogRepositoryProvider = Provider<ReviewLogRepository>(
  (ref) => DriftReviewLogRepository(ref.watch(databaseProvider)),
);

/// Runs several repository calls as one atomic unit.
final transactionRunnerProvider = Provider<TransactionRunner>(
  (ref) => DriftTransactionRunner(ref.watch(databaseProvider)),
);
