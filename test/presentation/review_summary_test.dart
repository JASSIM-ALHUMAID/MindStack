import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/cards.dart';
import 'package:mindstack/application/library.dart';
import 'package:mindstack/application/review.dart';
import 'package:mindstack/application/services.dart';
import 'package:mindstack/domain/enums.dart';
import 'package:mindstack/domain/models/deck.dart';
import 'package:mindstack/domain/models/flashcard.dart';
import 'package:mindstack/domain/models/review_log.dart';
import 'package:mindstack/domain/models/review_result.dart';
import 'package:mindstack/presentation/screens/review_screen.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

final _now = DateTime(2026, 11, 4, 12);
const _deck = Deck(id: 'deck', courseId: 'course', title: 'Deck');
final _first = Flashcard(
  id: 'first',
  deckId: _deck.id,
  question: 'First question',
  answer: 'First answer',
  dueAt: _now,
);
final _second = Flashcard(
  id: 'second',
  deckId: _deck.id,
  question: 'Second question',
  answer: 'Second answer',
  dueAt: _now,
);

// UI tests use fixed sessions. Database writes are covered by application tests.
class _ReviewStub extends ReviewNotifier {
  _ReviewStub(this.initial, {this.next});

  final ReviewState initial;
  final ReviewState? next;
  int startCalls = 0;

  @override
  Future<ReviewState> build() async => initial;

  @override
  Future<void> start({String? deckId, List<String>? cardIds}) async {
    startCalls++;
    final previous = state.requireValue;
    state = AsyncData(
      next ??
          ReviewState(
            cardIds: cardIds ?? previous.cardIds,
            sessionId: previous.sessionId + 1,
          ),
    );
  }
}

ProviderContainer _container(_ReviewStub notifier) {
  final c = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(FixedClock(_now)),
      reviewProvider.overrideWith(() => notifier),
      allCardsProvider.overrideWith((ref) => Stream.value([_first, _second])),
      decksProvider.overrideWith((ref) => Stream.value([_deck])),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void _viewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('empty queue shows completion and a way to check again', (
    tester,
  ) async {
    _viewport(tester);
    final notifier = _ReviewStub(
      const ReviewState(cardIds: [], sessionId: 1),
      next: const ReviewState(cardIds: ['first', 'second'], sessionId: 2),
    );
    final c = _container(notifier);
    await pumpInApp(tester, c, const ReviewScreen());
    await _pumpFrames(tester);

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('Nothing due right now.'), findsOneWidget);
    expect(find.text('0 CARDS REVIEWED'), findsOneWidget);
    expect(find.text('Check for due cards'), findsOneWidget);
    expect(find.textContaining('PACE:'), findsNothing);

    await tester.tap(find.text('Check for due cards'));
    await _pumpFrames(tester);

    expect(notifier.startCalls, 1);
    expect(find.text('First question'), findsOneWidget);
    expect(find.text('Nothing due right now.'), findsNothing);
  });

  testWidgets(
    'completion displays the real count, elapsed time, pace and due date',
    (tester) async {
      _viewport(tester);
      final summary = ReviewState(
        cardIds: const ['first', 'second'],
        index: 2,
        sessionId: 1,
        results: [
          ReviewResult(
            card: _first.copyWith(
              intervalDays: 1,
              repetitions: 1,
              dueAt: _now.add(const Duration(days: 1)),
            ),
            log: ReviewLog(
              id: 'log-first',
              cardId: _first.id,
              reviewedAt: _now,
              rating: Rating.good,
              elapsedMs: 2000,
            ),
          ),
          ReviewResult(
            card: _second.copyWith(
              intervalDays: 4,
              repetitions: 1,
              dueAt: _now.add(const Duration(days: 4)),
            ),
            log: ReviewLog(
              id: 'log-second',
              cardId: _second.id,
              reviewedAt: _now,
              rating: Rating.easy,
              elapsedMs: 5000,
            ),
          ),
        ],
      );
      final c = _container(_ReviewStub(summary));
      await pumpInApp(tester, c, const ReviewScreen());
      await _pumpFrames(tester);

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('2 CARDS REVIEWED'), findsOneWidget);
      expect(find.text('TIME: 7.0 S'), findsOneWidget);
      expect(find.text('PACE: 3.5 S/CARD'), findsOneWidget);
      expect(find.text('NEXT DUE: TOMORROW'), findsOneWidget);
      expect(find.text('First question'), findsOneWidget);
      expect(find.text('Second question'), findsOneWidget);
    },
  );

  testWidgets('a finished session with no ratings shows zero reviewed', (
    tester,
  ) async {
    _viewport(tester);
    final c = _container(
      _ReviewStub(
        const ReviewState(cardIds: ['first', 'second'], index: 2, sessionId: 1),
      ),
    );
    await pumpInApp(tester, c, const ReviewScreen());
    await _pumpFrames(tester);

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('0 CARDS REVIEWED'), findsOneWidget);
    expect(find.text('No cards were rated in this session.'), findsOneWidget);
    expect(find.text('CARDS REVIEWED'), findsNothing);
  });

  testWidgets('a new session hides the answer even for the same card', (
    tester,
  ) async {
    _viewport(tester);
    final notifier = _ReviewStub(
      const ReviewState(cardIds: ['first'], sessionId: 1),
    );
    final c = _container(notifier);
    await pumpInApp(tester, c, const ReviewScreen());
    await _pumpFrames(tester);
    await tester.tap(find.text('First question'));
    await tester.pump();
    expect(find.text('First answer'), findsOneWidget);

    await notifier.start(cardIds: ['first']);
    await _pumpFrames(tester);

    expect(find.text('First question'), findsOneWidget);
    expect(find.text('First answer'), findsNothing);
  });
}
