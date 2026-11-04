/// Source of the current time. Inject it so time-dependent logic is
/// deterministic in tests.
abstract interface class Clock {
  /// The current local date and time.
  DateTime now();
}

/// The production [Clock], backed by the system time.
final class SystemClock implements Clock {
  /// Creates a clock reading the system time.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
