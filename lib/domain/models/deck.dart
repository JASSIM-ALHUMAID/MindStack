/// A named group of flashcards inside a course.
class Deck {
  /// Creates a deck.
  const Deck({required this.id, required this.courseId, required this.title});

  /// Stable unique id.
  final String id;

  /// Id of the course this deck belongs to.
  final String courseId;

  /// Deck name, unique within its course ignoring letter case.
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
