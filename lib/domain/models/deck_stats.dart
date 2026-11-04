/// Aggregate figures for one deck.
class DeckStats {
  /// Creates the stats of deck [deckId].
  const DeckStats({
    required this.deckId,
    required this.cardCount,
    required this.mastery,
  });

  /// The deck these figures describe.
  final String deckId;

  /// Number of cards in the deck.
  final int cardCount;

  /// Average card mastery, 0.0 to 1.0 (0 for an empty deck).
  final double mastery;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeckStats &&
          other.deckId == deckId &&
          other.cardCount == cardCount &&
          other.mastery == mastery;

  @override
  int get hashCode => Object.hash(deckId, cardCount, mastery);

  @override
  String toString() =>
      'DeckStats(deckId: $deckId, cardCount: $cardCount, mastery: $mastery)';
}
