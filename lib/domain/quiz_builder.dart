import 'dart:math';

import 'enums.dart';
import 'models/flashcard.dart';
import 'models/quiz_question.dart';

/// Fewest cards that can make a question: one right answer and three wrong.
const int kMinQuizCards = 4;

/// Builds up to [count] multiple-choice questions from [cards].
///
/// Each question asks one card's question. Its options are that card's
/// answer plus three different answers from other cards, taken from the same
/// deck first, in shuffled order. [QuizQuestion.id] is the card's id, so a
/// missed question can be traced back to its card. The explanation is the
/// card's answer. Difficulty follows the card's mastery and sets the points:
/// easy 1, moderate and hard 2.
///
/// Returns an empty list when there are fewer than [kMinQuizCards] cards. A
/// card is left out when the others hold fewer than three distinct answers
/// that differ from its own. Pass a seeded [random] for a repeatable quiz.
List<QuizQuestion> buildQuiz(
  List<Flashcard> cards, {
  int count = 5,
  Random? random,
}) {
  if (cards.length < kMinQuizCards || count <= 0) return const [];
  final rng = random ?? Random();
  final order = [...cards]..shuffle(rng);
  final questions = <QuizQuestion>[];
  for (final card in order) {
    if (questions.length == count) break;
    final distractors = _distractors(card, cards, rng);
    if (distractors == null) continue;
    final options = [card.answer, ...distractors]..shuffle(rng);
    final difficulty = _difficulty(card.mastery);
    questions.add(
      QuizQuestion(
        id: card.id,
        prompt: card.question,
        options: options,
        correctIndex: options.indexOf(card.answer),
        explanation: card.answer,
        points: difficulty == Difficulty.easy ? 1 : 2,
        difficulty: difficulty,
      ),
    );
  }
  return questions;
}

/// Three answers from [all] that differ from [card]'s answer and from each
/// other (ignoring case and outer spaces), same deck first; null if there
/// are not enough.
List<String>? _distractors(Flashcard card, List<Flashcard> all, Random rng) {
  final sameDeck = <Flashcard>[];
  final otherDecks = <Flashcard>[];
  for (final other in all) {
    if (other.id == card.id) continue;
    (other.deckId == card.deckId ? sameDeck : otherDecks).add(other);
  }
  sameDeck.shuffle(rng);
  otherDecks.shuffle(rng);
  final seen = {_key(card.answer)};
  final picked = <String>[];
  for (final other in [...sameDeck, ...otherDecks]) {
    if (seen.add(_key(other.answer))) picked.add(other.answer);
    if (picked.length == 3) return picked;
  }
  return null;
}

String _key(String answer) => answer.trim().toLowerCase();

Difficulty _difficulty(double mastery) => mastery >= 0.7
    ? Difficulty.easy
    : (mastery >= 0.4 ? Difficulty.moderate : Difficulty.hard);
