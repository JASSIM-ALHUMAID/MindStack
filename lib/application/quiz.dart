import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import '../domain/failures.dart';
import '../domain/models/quiz_question.dart';
import '../domain/quiz_builder.dart';
import 'cards.dart';
import 'core_providers.dart';
import 'services.dart';

/// One quiz run: the questions, the position, and the answers so far.
@immutable
class QuizState {
  final List<QuizQuestion> questions;
  final int index;

  /// Option the user tapped for the current question, null if not answered.
  final int? selected;
  final int score;

  /// Indexes of the questions answered wrong (shown as weak cards on results).
  final List<int> missed;

  /// Time spent on the questions answered so far.
  final int elapsedMs;

  const QuizState({
    required this.questions,
    this.index = 0,
    this.selected,
    this.score = 0,
    this.missed = const [],
    this.elapsedMs = 0,
  });

  bool get finished => index >= questions.length;
  QuizQuestion? get current => finished ? null : questions[index];

  /// Ids of the cards behind the missed questions, in quiz order.
  List<String> get missedCardIds => [for (final i in missed) questions[i].id];

  /// Questions answered so far, including the current one once picked.
  int get answeredCount =>
      finished ? questions.length : index + (selected == null ? 0 : 1);

  double get secondsPerQuestion =>
      answeredCount == 0 ? 0 : elapsedMs / 1000 / answeredCount;

  /// Whether the user has not answered anything yet.
  bool get untouched => index == 0 && selected == null;
}

/// Shuffles the quiz. Override in tests with a seeded [Random].
final quizRandomProvider = Provider<Random>((ref) => Random());

/// The quiz, built from the stored cards when it starts.
class QuizNotifier extends AsyncNotifier<QuizState> {
  DateTime? _questionShownAt;

  @override
  Future<QuizState> build() async {
    final cards = await ref.read(cardRepositoryProvider).watchAll().first;
    _questionShownAt = ref.read(clockProvider).now();
    return QuizState(
      questions: buildQuiz(cards, random: ref.read(quizRandomProvider)),
    );
  }

  /// Answers the current question with [option]. A wrong answer is logged as
  /// [Rating.again] for its card, which also makes that card due again.
  ///
  /// The answer is shown right away; the log is written after. Throws
  /// [NotFound] if the card was deleted since the quiz started and
  /// [StorageFailure] if the write fails; the quiz itself carries on.
  Future<void> select(int option) async {
    final quiz = state.valueOrNull;
    final question = quiz?.current;
    if (quiz == null || question == null || quiz.selected != null) return;
    final now = ref.read(clockProvider).now();
    final elapsed = now.difference(_questionShownAt ?? now).inMilliseconds;
    final elapsedMs = elapsed < 0 ? 0 : elapsed;
    final correct = option == question.correctIndex;
    state = AsyncData(
      QuizState(
        questions: quiz.questions,
        index: quiz.index,
        selected: option,
        score: quiz.score + (correct ? 1 : 0),
        missed: correct ? quiz.missed : [...quiz.missed, quiz.index],
        elapsedMs: quiz.elapsedMs + elapsedMs,
      ),
    );
    if (!correct) {
      await ref
          .read(cardCommandsProvider)
          .recordRating(question.id, Rating.again, elapsedMs: elapsedMs);
    }
  }

  /// Moves to the next question, or to the results after the last one.
  void next() {
    final quiz = state.valueOrNull;
    if (quiz == null || quiz.finished || quiz.selected == null) return;
    _questionShownAt = ref.read(clockProvider).now();
    state = AsyncData(
      QuizState(
        questions: quiz.questions,
        index: quiz.index + 1,
        score: quiz.score,
        missed: quiz.missed,
        elapsedMs: quiz.elapsedMs,
      ),
    );
  }

  /// "Try again": a new quiz from the cards stored now.
  void restart() => ref.invalidateSelf();

  /// Rebuilds the quiz when the user is not in the middle of one, so cards
  /// added or deleted since it was built are used. Called when the Quiz tab
  /// opens.
  void refreshIfIdle() {
    final quiz = state.valueOrNull;
    if (state.isLoading) return;
    if (quiz == null ||
        quiz.questions.isEmpty ||
        quiz.finished ||
        quiz.untouched) {
      ref.invalidateSelf();
    }
  }
}

final quizProvider = AsyncNotifierProvider<QuizNotifier, QuizState>(
  QuizNotifier.new,
);
