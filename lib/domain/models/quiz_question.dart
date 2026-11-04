import '../enums.dart';

/// A multiple-choice quiz question.
class QuizQuestion {
  /// Creates a question; [correctIndex] indexes into [options].
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.points = 2,
    this.difficulty = Difficulty.moderate,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int points;
  final Difficulty difficulty;

  bool _sameOptions(List<String> other) {
    if (other.length != options.length) return false;
    for (var i = 0; i < options.length; i++) {
      if (other[i] != options[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizQuestion &&
          other.id == id &&
          other.prompt == prompt &&
          _sameOptions(other.options) &&
          other.correctIndex == correctIndex &&
          other.explanation == explanation &&
          other.points == points &&
          other.difficulty == difficulty;

  @override
  int get hashCode => Object.hash(
    id,
    prompt,
    Object.hashAll(options),
    correctIndex,
    explanation,
    points,
    difficulty,
  );

  @override
  String toString() =>
      'QuizQuestion(id: $id, prompt: $prompt, '
      'options: $options, correctIndex: $correctIndex, '
      'explanation: $explanation, points: $points, '
      'difficulty: ${difficulty.name})';
}
