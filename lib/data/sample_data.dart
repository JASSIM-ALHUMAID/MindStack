import '../core/dates.dart';
import '../domain/enums.dart';
import '../domain/models/course.dart';
import '../domain/models/deck.dart';
import '../domain/models/draft_card.dart';
import '../domain/models/flashcard.dart';
import 'seed.dart';

/// Builds the sample library that [seedIfNeeded] stores on first launch, so
/// the app opens with the same content as the Figma screens. Exam dates and
/// card due times are relative to [now].
SeedData buildSampleData(DateTime now) {
  final courses = [
    Course(
      id: 'c1',
      title: 'SWE 463 · Mobile App Dev',
      examDate: dateOnly(now.add(const Duration(days: 21))),
    ),
    Course(
      id: 'c2',
      title: 'SWE 463 · Flutter Lab',
      examDate: dateOnly(now.add(const Duration(days: 14))),
    ),
  ];

  const decks = [
    Deck(id: 'd1', courseId: 'c1', title: 'Flutter Widgets'),
    Deck(id: 'd2', courseId: 'c1', title: 'Dart fundamentals'),
    Deck(id: 'd3', courseId: 'c2', title: 'Riverpod state'),
    Deck(id: 'd4', courseId: 'c2', title: 'Navigation & routing'),
  ];

  Flashcard card(
    String id,
    String deckId,
    String q,
    String a,
    double mastery,
    int reps,
    int interval,
  ) {
    return Flashcard(
      id: id,
      deckId: deckId,
      question: q,
      answer: a,
      repetitions: reps,
      intervalDays: interval,
      mastery: mastery,
      dueAt: now.subtract(const Duration(hours: 1)),
    );
  }

  final cards = [
    card(
      'k1',
      'd1',
      'What is a Widget?',
      'The immutable building block of a Flutter UI.',
      0.84,
      4,
      4,
    ),
    card(
      'k2',
      'd1',
      'Stateless vs Stateful?',
      'Stateless rebuilds from config; Stateful keeps a mutable State object.',
      0.72,
      3,
      1,
    ),
    card(
      'k3',
      'd1',
      'What does setState() do?',
      'Marks the state dirty and schedules a rebuild.',
      0.40,
      0,
      0,
    ),
    card(
      'k4',
      'd1',
      'Define BuildContext.',
      "A handle to a widget's location in the element tree.",
      0.91,
      5,
      7,
    ),
    card(
      'k5',
      'd1',
      'What is hot reload?',
      'Injects changed source into the running Dart VM.',
      0.98,
      6,
      12,
    ),
    card(
      'k6',
      'd1',
      'What is the widget tree?',
      'The nested hierarchy of widgets describing the UI.',
      0.15,
      0,
      0,
    ),
    card(
      'k7',
      'd2',
      'What is null safety?',
      'A type system feature that separates nullable from non-nullable types.',
      0.41,
      2,
      1,
    ),
    card(
      'k8',
      'd3',
      'setState vs Riverpod?',
      'setState is local to one widget; Riverpod shares state across screens.',
      0.30,
      1,
      1,
    ),
    card(
      'k9',
      'd4',
      'Navigator stack order?',
      'Last pushed route is on top; pop removes the top route.',
      0.25,
      1,
      1,
    ),
  ];

  const drafts = [
    DraftCard(
      id: 'x1',
      source: CardSource.slide,
      sourceRef: 'Page 2',
      question: 'What is Flutter?',
      answer: "Google's UI toolkit for compiled native apps from a single codebase.",
    ),
    DraftCard(
      id: 'x2',
      source: CardSource.slide,
      sourceRef: 'Page 5',
      question: 'Define hot reload.',
      answer:
          'Inject updated code into the running VM without losing app state.',
    ),
    DraftCard(
      id: 'x3',
      source: CardSource.pdf,
      sourceRef: 'Lecture 1',
      question: 'What is a widget?',
      answer:
          'An immutable configuration object that describes part of the UI.',
    ),
    DraftCard(
      id: 'x4',
      source: CardSource.photo,
      sourceRef: 'Whiteboard #1',
      question: 'Name state-management options.',
      answer: 'setState, Provider, Riverpod, Bloc.',
    ),
  ];

  return SeedData(courses: courses, decks: decks, cards: cards, drafts: drafts);
}
