import '../models/course.dart';
import '../models/deck.dart';
import '../models/draft_card.dart';
import '../models/flashcard.dart';
import '../models/quiz_question.dart';

/// Local sample data for Phase 2. In Phase 3 this seeds the SQLite database
/// on first launch, so the app opens with the same content as the Figma screens.

final DateTime _now = DateTime.now();

final List<Course> sampleCourses = [
  Course(
    id: 'c1',
    title: 'SWE 463 · Mobile App Dev',
    examDate: _now.add(const Duration(days: 21)),
  ),
  Course(
    id: 'c2',
    title: 'SWE 463 · Flutter Lab',
    examDate: _now.add(const Duration(days: 14)),
  ),
];

const List<Deck> sampleDecks = [
  Deck(id: 'd1', courseId: 'c1', title: 'Flutter Widgets'),
  Deck(id: 'd2', courseId: 'c1', title: 'Dart fundamentals'),
  Deck(id: 'd3', courseId: 'c2', title: 'Riverpod state'),
  Deck(id: 'd4', courseId: 'c2', title: 'Navigation & routing'),
];

Flashcard _card(
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
    dueAt: _now.subtract(const Duration(hours: 1)),
  );
}

final List<Flashcard> sampleCards = [
  _card('k1', 'd1', 'What is a Widget?',
      'The immutable building block of a Flutter UI.', 0.84, 4, 4),
  _card('k2', 'd1', 'Stateless vs Stateful?',
      'Stateless rebuilds from config; Stateful keeps a mutable State object.', 0.72, 3, 1),
  _card('k3', 'd1', 'What does setState() do?',
      'Marks the state dirty and schedules a rebuild.', 0.40, 0, 0),
  _card('k4', 'd1', 'Define BuildContext.',
      "A handle to a widget's location in the element tree.", 0.91, 5, 7),
  _card('k5', 'd1', 'What is hot reload?',
      'Injects changed source into the running Dart VM.', 0.98, 6, 12),
  _card('k6', 'd1', 'What is the widget tree?',
      'The nested hierarchy of widgets describing the UI.', 0.15, 0, 0),
  _card('k7', 'd2', 'What is null safety?',
      'A type system feature that separates nullable from non-nullable types.', 0.41, 2, 1),
  _card('k8', 'd3', 'setState vs Riverpod?',
      'setState is local to one widget; Riverpod shares state across screens.', 0.30, 1, 1),
  _card('k9', 'd4', 'Navigator stack order?',
      'Last pushed route is on top; pop removes the top route.', 0.25, 1, 1),
];

const List<DraftCard> sampleDrafts = [
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
    answer: 'Inject updated code into the running VM without losing app state.',
  ),
  DraftCard(
    id: 'x3',
    source: CardSource.pdf,
    sourceRef: 'Lecture 1',
    question: 'What is a widget?',
    answer: 'An immutable configuration object that describes part of the UI.',
  ),
  DraftCard(
    id: 'x4',
    source: CardSource.photo,
    sourceRef: 'Whiteboard #1',
    question: 'Name state-management options.',
    answer: 'setState, Provider, Riverpod, Bloc.',
  ),
];

const List<QuizQuestion> sampleQuiz = [
  QuizQuestion(
    id: 'q1',
    prompt: 'A widget is best described as:',
    options: ['A mutable object', 'An immutable configuration', 'A native view', 'A database row'],
    correctIndex: 1,
    explanation: 'Widgets are immutable descriptions of part of the UI.',
  ),
  QuizQuestion(
    id: 'q2',
    prompt: 'setState() does what?',
    options: ['Saves to disk', 'Marks state dirty and schedules a rebuild', 'Creates a route', 'Closes the app'],
    correctIndex: 1,
    explanation: 'It tells the framework to call build() again.',
  ),
  QuizQuestion(
    id: 'q3',
    prompt: 'Hot reload injects code into:',
    options: ['A new VM', 'The running Dart VM', 'The native binary', 'A web server'],
    correctIndex: 1,
    explanation:
        'Hot reload pushes changed source into the running Dart VM and rebuilds the widget tree.',
  ),
  QuizQuestion(
    id: 'q4',
    prompt: 'Navigator.push() does:',
    options: ['Removes the top route', 'Adds a route to the stack', 'Replaces the app', 'Clears all routes'],
    correctIndex: 1,
    explanation: 'push adds a route on top of the stack; pop removes it.',
  ),
  QuizQuestion(
    id: 'q5',
    prompt: 'BuildContext is:',
    options: ['A handle to a location in the element tree', 'A theme', 'A network client', 'A state object'],
    correctIndex: 0,
    explanation: 'It identifies where a widget sits in the element tree.',
  ),
];
