import '../utils/format.dart';

class Course {
  final String id;
  final String title;
  final DateTime examDate;

  const Course({required this.id, required this.title, required this.examDate});

  /// Whole days from today until the exam (negative if the exam has passed).
  int daysToExam([DateTime? now]) {
    final today = dateOnly(now ?? DateTime.now());
    return dateOnly(examDate).difference(today).inDays;
  }
}
