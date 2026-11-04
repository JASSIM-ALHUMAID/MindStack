/// A named group of flashcards inside a course.
class Deck {
  /// Creates a deck.
  const Deck({required this.id, required this.courseId, required this.title});

  final String id;
  final String courseId;
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Deck &&
          other.id == id &&
          other.courseId == courseId &&
          other.title == title;

  @override
  int get hashCode => Object.hash(id, courseId, title);

  @override
  String toString() => 'Deck(id: $id, courseId: $courseId, title: $title)';
}
