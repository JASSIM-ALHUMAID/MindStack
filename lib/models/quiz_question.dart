enum Difficulty { easy, moderate, hard }

class QuizQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int points;
  final Difficulty difficulty;

  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.points = 2,
    this.difficulty = Difficulty.moderate,
  });
}
