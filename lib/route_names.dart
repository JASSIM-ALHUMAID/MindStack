/// Route paths used with go_router.
class RouteNames {
  RouteNames._();

  /// App shell with the bottom navigation bar.
  static const String home = '/';

  /// Deck Editor. The deck id is a path parameter: /deck/:deckId
  static const String deck = '/deck/:deckId';

  /// Builds the path for one deck, e.g. /deck/d1
  static String deckPath(String deckId) => '/deck/$deckId';
}
