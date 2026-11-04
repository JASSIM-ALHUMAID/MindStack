import '../domain/repositories.dart';
import 'database/app_database.dart';
import 'failure_mapping.dart';

/// [TransactionRunner] backed by a drift transaction. Rolls back when
/// [action] throws and reports failures as `AppFailure`s.
final class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() action) =>
      guard(() => _db.transaction(action));
}
