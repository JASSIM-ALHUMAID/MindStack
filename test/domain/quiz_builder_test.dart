import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/quiz_builder.dart';

Flashcard _card(
  String id, {
  String deck = 'd1',
  String? answer,
  double mastery = 0,
}) => Flashcard(
  id: id,
  deckId: deck,
  question: 'Question $id',
  answer: answer ?? 'Answer $id',
  dueAt: DateTime(2026, 11, 4),
  mastery: mastery,
);

List<Flashcard> _cards(int n) => [for (var i = 1; i <= n; i++) _card('k$i')];

void main() {
  test('buildQuiz returns 5 questions with 4 distinct options each', () {
    final quiz = buildQuiz(_cards(8), random: Random(1));

    expect(quiz, hasLength(5));
    expect({for (final q in quiz) q.id}, hasLength(5));
    for (final q in quiz) {
      expect(q.options, hasLength(4));
      expect(q.options.toSet(), hasLength(4));
    }
  });

  test('correctIndex points at the card answer', () {
    final cards = _cards(6);
    final byId = {for (final c in cards) c.id: c};

    final quiz = buildQuiz(cards, random: Random(42));

    for (final q in quiz) {
      final card = byId[q.id]!;
      expect(q.prompt, card.question);
      expect(q.options[q.correctIndex], card.answer);
      expect(q.explanation, card.answer);
    }
  });

  test('the same seed builds the same quiz', () {
    final cards = _cards(10);
    expect(
      buildQuiz(cards, random: Random(7)),
      buildQuiz(cards, random: Random(7)),
    );
  });

  test('fewer than 4 cards returns empty list', () {
    expect(buildQuiz(const []), isEmpty);
    expect(buildQuiz(_cards(3)), isEmpty);
    expect(buildQuiz(_cards(4)), hasLength(4));
  });

  test('distractors come from the same deck first', () {
    final cards = [
      for (var i = 1; i <= 4; i++) _card('a$i', deck: 'A'),
      for (var i = 1; i <= 4; i++) _card('b$i', deck: 'B'),
    ];
    final deckOf = {for (final c in cards) c.answer: c.deckId};

    final quiz = buildQuiz(cards, count: 8, random: Random(3));

    expect(quiz, hasLength(8));
    for (final q in quiz) {
      final deck = deckOf[q.options[q.correctIndex]];
      expect(q.options.every((o) => deckOf[o] == deck), isTrue);
    }
  });

  test('a card without 3 different other answers is left out', () {
    final cards = [
      _card('k1', answer: 'Same'),
      _card('k2', answer: ' same '),
      _card('k3', answer: 'SAME'),
      _card('k4', answer: 'Other'),
    ];

    // k4 has only one distinct other answer; k1..k3 have only "Other".
    expect(buildQuiz(cards, random: Random(1)), isEmpty);
  });

  test('difficulty and points follow mastery', () {
    final cards = [
      _card('easy', mastery: 0.9),
      _card('moderate', mastery: 0.5),
      _card('hard', mastery: 0.1),
      _card('filler'),
    ];

    final quiz = {for (final q in buildQuiz(cards, random: Random(1))) q.id: q};

    expect(
      (quiz['easy']!.difficulty, quiz['easy']!.points),
      (Difficulty.easy, 1),
    );
    expect(
      (quiz['moderate']!.difficulty, quiz['moderate']!.points),
      (Difficulty.moderate, 2),
    );
    expect(
      (quiz['hard']!.difficulty, quiz['hard']!.points),
      (Difficulty.hard, 2),
    );
  });
}
