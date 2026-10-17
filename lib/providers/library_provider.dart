import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_data.dart';
import '../models/course.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';

class CoursesNotifier extends Notifier<List<Course>> {
  @override
  List<Course> build() => List<Course>.of(sampleCourses);

  void add({required String title, required DateTime examDate}) {
    final id = 'c${DateTime.now().microsecondsSinceEpoch}';
    state = [...state, Course(id: id, title: title, examDate: examDate)];
  }
}

final coursesProvider =
    NotifierProvider<CoursesNotifier, List<Course>>(CoursesNotifier.new);

class DecksNotifier extends Notifier<List<Deck>> {
  @override
  List<Deck> build() => List<Deck>.of(sampleDecks);

  /// Creates an empty deck in [courseId] and returns its id.
  String add({required String courseId, required String title}) {
    final id = 'd${DateTime.now().microsecondsSinceEpoch}';
    state = [...state, Deck(id: id, courseId: courseId, title: title)];
    return id;
  }

  void remove(String id) => state = state.where((d) => d.id != id).toList();
}

final decksProvider =
    NotifierProvider<DecksNotifier, List<Deck>>(DecksNotifier.new);

class CardsNotifier extends Notifier<List<Flashcard>> {
  @override
  List<Flashcard> build() => List<Flashcard>.of(sampleCards);

  void add(Flashcard card) => state = [...state, card];

  void addAll(Iterable<Flashcard> cards) => state = [...state, ...cards];

  void remove(String id) => state = state.where((c) => c.id != id).toList();

  /// Moves every card of [fromDeckId] into [toDeckId] (deck merging).
  void moveToDeck(String fromDeckId, String toDeckId) {
    state = [
      for (final c in state) c.deckId == fromDeckId ? c.copyWith(deckId: toDeckId) : c,
    ];
  }

  void rate(String id, Rating rating) {
    state = [
      for (final c in state) c.id == id ? c.applyRating(rating) : c,
    ];
  }
}

final cardsProvider =
    NotifierProvider<CardsNotifier, List<Flashcard>>(CardsNotifier.new);

final deckCardsProvider = Provider.family<List<Flashcard>, String>((ref, deckId) {
  return ref.watch(cardsProvider).where((c) => c.deckId == deckId).toList();
});

/// Average mastery of a deck, 0.0 to 1.0.
final deckMasteryProvider = Provider.family<double, String>((ref, deckId) {
  final cards = ref.watch(deckCardsProvider(deckId));
  if (cards.isEmpty) return 0;
  final total = cards.fold<double>(0, (sum, c) => sum + c.mastery);
  return total / cards.length;
});
