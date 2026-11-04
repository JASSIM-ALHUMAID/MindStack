import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mindstack/data/database/app_database.dart';

/// Opens a fresh in-memory [AppDatabase]. Callers own it and must close it,
/// typically with `addTearDown(db.close)`.
///
/// Streams close synchronously so widget tests do not end with pending
/// stream-cleanup timers.
AppDatabase openTestDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
