import 'package:drift/native.dart';
import 'package:mindstack/data/database/app_database.dart';

/// Opens a fresh in-memory [AppDatabase]. Callers own it and must close it,
/// typically with `addTearDown(db.close)`.
AppDatabase openTestDatabase() => AppDatabase(NativeDatabase.memory());
