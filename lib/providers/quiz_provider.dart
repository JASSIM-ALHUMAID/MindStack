import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_data.dart';
import '../models/quiz_question.dart';

class QuizState {
  final List<QuizQuestion> questions;
  final int index;

  /// Option the user tapped for the current question, null if not answered.
  final int? selected;
  final int score;

  /// Indexes of the questions answered wrong (shown as weak cards on results).
  final List<int> missed;

  const QuizState({
    required this.questions,
    this.index = 0,
    this.selected,
    this.score = 0,
    this.missed = const [],
  });

  bool get finished => index >= questions.length;
  QuizQuestion? get current => finished ? null : questions[index];
}

class QuizNotifier extends Notifier<QuizState> {
  @override
  QuizState build() => const QuizState(questions: sampleQuiz);

  void select(int option) {
    final q = state.current;
    if (q == null || state.selected != null) return;
    final correct = option == q.correctIndex;
    state = QuizState(
      questions: state.questions,
      index: state.index,
      selected: option,
      score: state.score + (correct ? 1 : 0),
      missed: correct ? state.missed : [...state.missed, state.index],
    );
  }

  void next() {
    state = QuizState(
      questions: state.questions,
      index: state.index + 1,
      score: state.score,
      missed: state.missed,
    );
  }

  void restart() => state = const QuizState(questions: sampleQuiz);
}

final quizProvider = NotifierProvider<QuizNotifier, QuizState>(QuizNotifier.new);
