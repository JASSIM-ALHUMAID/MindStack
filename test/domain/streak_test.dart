import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/streak.dart';

final _now = DateTime(2026, 11, 14, 18);

/// A review at 10:00 on the day [daysAgo] days before [_now].
DateTime _ago(int daysAgo, {int hour = 10}) =>
    DateTime(_now.year, _now.month, _now.day - daysAgo, hour);

void main() {
  test('3 consecutive review days give current streak 3', () {
    final streak = computeStreak([_ago(0), _ago(1), _ago(2)], _now);

    expect(streak.current, 3);
    expect(streak.best, 3);
    expect(streak.studyDays, 3);
    expect(streak.days.sublist(25), [true, true, true]);
  });

  test('no reviews gives streak 0', () {
    final streak = computeStreak(const [], _now);

    expect(streak.current, 0);
    expect(streak.best, 0);
    expect(streak.isEmpty, isTrue);
    expect(streak.days, List.filled(kStreakGridDays, false));
  });

  test('gap day resets current but not best', () {
    // A 4-day run, a missed day, then today and yesterday.
    final streak = computeStreak([
      for (final d in [6, 5, 4, 3, 1, 0]) _ago(d),
    ], _now);

    expect(streak.current, 2);
    expect(streak.best, 4);
  });

  test('a streak that reached yesterday still counts before today ends', () {
    final streak = computeStreak([_ago(1), _ago(2)], _now);

    expect(streak.current, 2);
    expect(streak.days.last, isFalse);
  });

  test('a streak that ended two days ago is broken', () {
    final streak = computeStreak([_ago(2), _ago(3)], _now);

    expect(streak.current, 0);
    expect(streak.best, 2);
  });

  test('several reviews on one day count once', () {
    final streak = computeStreak([
      _ago(0, hour: 8),
      _ago(0, hour: 23),
      _ago(0, hour: 0),
    ], _now);

    expect((streak.current, streak.best, streak.studyDays), (1, 1, 1));
  });

  test('reviews older than the grid count for best, not for the grid', () {
    final streak = computeStreak([for (var d = 40; d < 45; d++) _ago(d)], _now);

    expect(streak.best, 5);
    expect(streak.current, 0);
    expect(streak.studyDays, 0);
  });

  test('dayAt gives the calendar date of each cell, ending today', () {
    final streak = computeStreak(const [], _now);

    expect(streak.dayAt(kStreakGridDays - 1), DateTime(2026, 11, 14));
    expect(streak.dayAt(0), DateTime(2026, 10, 18));
  });

  test('runs across a month end are consecutive', () {
    final streak = computeStreak([
      DateTime(2026, 10, 31, 9),
      DateTime(2026, 11, 1, 9),
    ], DateTime(2026, 11, 1, 20));

    expect(streak.current, 2);
  });
}
