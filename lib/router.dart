import 'package:go_router/go_router.dart';

import 'route_names.dart';
import 'screens/app_shell.dart';
import 'screens/deck_editor_screen.dart';

/// All app routes. The five tabs live inside AppShell (bottom navigation);
/// Deck Editor is pushed on top of it.
final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.home,
  routes: [
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const AppShell(),
    ),
    GoRoute(
      path: RouteNames.deck,
      builder: (context, state) =>
          DeckEditorScreen(deckId: state.pathParameters['deckId']!),
    ),
  ],
);
