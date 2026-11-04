import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/failures.dart';

void main() {
  test('NotFound message', () {
    expect(
      const NotFound(entity: 'deck', id: 'd1').userMessage,
      'That item no longer exists.',
    );
  });

  test('Conflict messages', () {
    expect(
      const Conflict(ConflictKind.duplicateId).userMessage,
      "Couldn't save. Please try again.",
    );
    expect(
      const Conflict(ConflictKind.duplicateTitle).userMessage,
      'A deck with this name already exists in this course.',
    );
  });

  test('InvalidInput message is its reason', () {
    expect(
      const InvalidInput(
        field: 'title',
        reason: 'Enter a deck name.',
      ).userMessage,
      'Enter a deck name.',
    );
  });

  test('StorageFailure message is generic and toString has the cause', () {
    final failure = StorageFailure('disk exploded', StackTrace.current);
    expect(failure.userMessage, "Couldn't save. Please try again.");
    expect(failure.toString(), contains('disk exploded'));
  });

  test('every failure is an AppFailure and an Exception', () {
    const Exception failure = NotFound(entity: 'card', id: 'c');
    expect(failure, isA<AppFailure>());
  });
}
