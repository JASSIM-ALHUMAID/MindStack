import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/models/course.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/models/deck_stats.dart';
import 'package:mindstack/domain/models/draft_card.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/models/quiz_question.dart';
import 'package:mindstack/domain/models/review_log.dart';

void main() {
  final due = DateTime(2026, 1, 10);

  Flashcard card({double mastery = 0.5}) => Flashcard(
    id: 'c1',
    deckId: 'd1',
    question: 'Q',
    answer: 'A',
    dueAt: due,
    mastery: mastery,
  );

  group('Flashcard', () {
    test('equal fields are equal and share a hash code', () {
      expect(card(), card());
      expect(card().hashCode, card().hashCode);
    });

    test('differing mastery is not equal', () {
      expect(card(), isNot(card(mastery: 0.6)));
    });
  });

  group('Course.daysToExam', () {
    final now = DateTime(2026, 1, 10, 23, 59);
    Course course(DateTime exam) => Course(id: 'x', title: 'T', examDate: exam);

    test('tomorrow is 1', () {
      expect(course(DateTime(2026, 1, 11)).daysToExam(now), 1);
    });

    test('today is 0', () {
      expect(course(DateTime(2026, 1, 10)).daysToExam(now), 0);
    });

    test('yesterday is -1', () {
      expect(course(DateTime(2026, 1, 9)).daysToExam(now), -1);
    });
  });

  test('Deck and Course are value types', () {
    expect(
      const Deck(id: 'd', courseId: 'c', title: 'T'),
      const Deck(id: 'd', courseId: 'c', title: 'T'),
    );
    expect(
      Course(id: 'c', title: 'T', examDate: due),
      Course(id: 'c', title: 'T', examDate: due),
    );
  });

  test('DeckStats, ReviewLog, DraftCard and QuizQuestion are value types', () {
    expect(
      const DeckStats(deckId: 'd', cardCount: 2, mastery: 0.5),
      const DeckStats(deckId: 'd', cardCount: 2, mastery: 0.5),
    );
    expect(
      ReviewLog(
        id: 'l',
        cardId: 'c',
        reviewedAt: due,
        rating: Rating.good,
        elapsedMs: 5,
      ),
      ReviewLog(
        id: 'l',
        cardId: 'c',
        reviewedAt: due,
        rating: Rating.good,
        elapsedMs: 5,
      ),
    );
    expect(
      const DraftCard(
        id: 'x',
        source: CardSource.pdf,
        sourceRef: 'p1',
        question: 'q',
        answer: 'a',
      ),
      const DraftCard(
        id: 'x',
        source: CardSource.pdf,
        sourceRef: 'p1',
        question: 'q',
        answer: 'a',
      ),
    );
    QuizQuestion q() => const QuizQuestion(
      id: 'q',
      prompt: 'p',
      options: ['a', 'b'],
      correctIndex: 0,
      explanation: 'e',
    );
    expect(q(), q());
    expect(q().hashCode, q().hashCode);
  });
}
