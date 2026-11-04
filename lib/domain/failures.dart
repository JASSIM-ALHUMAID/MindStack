/// Why a repository or command call failed. Repositories throw only these;
/// storage-specific exceptions never cross the data layer boundary.
sealed class AppFailure implements Exception {
  const AppFailure();

  /// Plain-language text that is safe to show to the user.
  String get userMessage;
}

/// The targeted entity does not exist (any more).
final class NotFound extends AppFailure {
  /// Creates a failure for the [entity] kind with the missing [id].
  const NotFound({required this.entity, required this.id});

  /// Kind of entity, for example `deck`.
  final String entity;

  /// Id that was looked up.
  final String id;

  @override
  String get userMessage => 'That item no longer exists.';

  @override
  String toString() => 'NotFound(entity: $entity, id: $id)';
}

/// Which uniqueness rule a [Conflict] broke.
enum ConflictKind { duplicateId, duplicateTitle }

/// A write collided with existing data.
final class Conflict extends AppFailure {
  /// Creates a conflict of the given [kind].
  const Conflict(this.kind);

  /// The rule that was broken.
  final ConflictKind kind;

  @override
  String get userMessage => switch (kind) {
    ConflictKind.duplicateId => "Couldn't save. Please try again.",
    ConflictKind.duplicateTitle =>
      'A deck with this name already exists in this course.',
  };

  @override
  String toString() => 'Conflict(${kind.name})';
}

/// The input was rejected before or by the store.
final class InvalidInput extends AppFailure {
  /// Creates a failure for [field] explained to the user by [reason].
  const InvalidInput({required this.field, required this.reason});

  /// Name of the offending field.
  final String field;

  /// User-facing explanation, for example `Enter a deck name.`.
  final String reason;

  @override
  String get userMessage => reason;

  @override
  String toString() => 'InvalidInput(field: $field, reason: $reason)';
}

/// Any other storage error. The user gets a generic message; [cause] and
/// [stack] are for the log.
final class StorageFailure extends AppFailure {
  /// Wraps the underlying [cause] raised at [stack].
  const StorageFailure(this.cause, this.stack);

  /// The original error.
  final Object cause;

  /// Where the original error was raised.
  final StackTrace stack;

  @override
  String get userMessage => "Couldn't save. Please try again.";

  @override
  String toString() => 'StorageFailure(cause: $cause)';
}
