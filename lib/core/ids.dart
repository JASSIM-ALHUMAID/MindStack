import 'package:uuid/uuid.dart';

/// Mints unique ids for new entities. Inject it so tests get stable ids.
abstract interface class IdGenerator {
  /// Returns a new unique id.
  String newId();
}

/// The production [IdGenerator]: random (version 4) UUIDs.
final class UuidGenerator implements IdGenerator {
  /// Creates a generator of random UUIDs.
  UuidGenerator() : _uuid = const Uuid();

  final Uuid _uuid;

  @override
  String newId() => _uuid.v4();
}
