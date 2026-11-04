import '../../core/dates.dart';

/// A course with an exam date.
class Course {
  /// Creates a course. [examDate] is a calendar date (local midnight).
  const Course({required this.id, required this.title, required this.examDate});

  /// Stable unique id.
  final String id;

  /// Course name, for example "Mobile Development".
  final String title;

  /// Exam day as a calendar date (local midnight).
  final DateTime examDate;

  /// Whole days from [now]'s date until the exam (negative once it passed).
  int daysToExam(DateTime now) {
    return dateOnly(examDate).difference(dateOnly(now)).inDays;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Course &&
          other.id == id &&
          other.title == title &&
          other.examDate == examDate;

  @override
  int get hashCode => Object.hash(id, title, examDate);

  @override
  String toString() => 'Course(id: $id, title: $title, examDate: $examDate)';
}
