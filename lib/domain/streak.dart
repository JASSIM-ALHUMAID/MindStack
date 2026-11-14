/// Number of days shown in the Stats streak grid.
const int kStreakGridDays = 28;

/// Study streak figures computed from review times.
class StreakInfo {
  /// Creates the figures; [days] is oldest first and ends with [today].
  const StreakInfo({
    required this.current,
    required this.best,
    required this.today,
    required this.days,
  });

  /// Consecutive study days up to today. A streak that reached yesterday
  /// still counts until today ends without a review.
  final int current;

  /// Longest run of consecutive study days ever.
  final int best;

  /// The calendar date the figures were computed for.
  final DateTime today;

  /// One entry per day of the last [kStreakGridDays] days, oldest first;
  /// true when at least one card was reviewed that day.
  final List<bool> days;

  /// The calendar date of grid cell [index].
  DateTime dayAt(int index) =>
      DateTime(today.year, today.month, today.day - (days.length - 1 - index));

  /// Days in the grid with at least one review.
  int get studyDays => days.where((d) => d).length;

  /// Whether nothing has ever been reviewed.
  bool get isEmpty => best == 0;

  bool _sameDays(List<bool> other) {
    if (other.length != days.length) return false;
    for (var i = 0; i < days.length; i++) {
      if (other[i] != days[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is StreakInfo &&
      other.current == current &&
      other.best == best &&
      other.today == today &&
      _sameDays(other.days);

  @override
  int get hashCode => Object.hash(current, best, today, Object.hashAll(days));

  @override
  String toString() =>
      'StreakInfo(current: $current, best: $best, today: $today, '
      'studyDays: $studyDays)';
}

/// Computes the streak from the local times of every review, as of [now].
/// Reviews dated after today are ignored.
StreakInfo computeStreak(Iterable<DateTime> reviewedAt, DateTime now) {
  final today = _dayNumber(now);
  final studied = {
    for (final t in reviewedAt)
      if (_dayNumber(t) <= today) _dayNumber(t),
  };

  var best = 0;
  for (final day in studied) {
    // Count each run once, from its first day.
    if (studied.contains(day - 1)) continue;
    var length = 1;
    while (studied.contains(day + length)) {
      length++;
    }
    if (length > best) best = length;
  }

  var end = today;
  if (!studied.contains(end)) end--;
  var current = 0;
  while (studied.contains(end - current)) {
    current++;
  }

  return StreakInfo(
    current: current,
    best: best,
    today: DateTime(now.year, now.month, now.day),
    days: [
      for (var i = kStreakGridDays - 1; i >= 0; i--)
        studied.contains(today - i),
    ],
  );
}

/// Days since the epoch for the calendar date of [t]. Counted in UTC so a
/// daylight-saving change cannot make a day 23 or 25 hours long.
int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
