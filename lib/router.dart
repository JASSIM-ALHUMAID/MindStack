import 'package:go_router/go_router.dart';

import 'presentation/screens/app_shell.dart';
import 'presentation/screens/deck_editor_screen.dart';
import 'route_names.dart';

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
