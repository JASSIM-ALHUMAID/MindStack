import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/tab_provider.dart';
import 'inbox_screen.dart';
import 'library_screen.dart';
import 'quiz_screen.dart';
import 'review_screen.dart';
import 'stats_screen.dart';

/// Hosts the five main tabs behind a Material 3 NavigationBar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<Widget> _pages = [
    InboxScreen(),
    LibraryScreen(),
    ReviewScreen(),
    QuizScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);
    return PopScope(
      // Library is the start tab. Back from any other tab returns to Library first.
      canPop: index == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) ref.read(tabIndexProvider.notifier).set(1);
      },
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(index: index, children: _pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => ref.read(tabIndexProvider.notifier).set(i),
          destinations: const [
            NavigationDestination(icon: Icon(LucideIcons.inbox), label: 'INBOX'),
            NavigationDestination(icon: Icon(LucideIcons.book), label: 'LIBRARY'),
            NavigationDestination(icon: Icon(LucideIcons.bookOpen), label: 'REVIEW'),
            NavigationDestination(icon: Icon(LucideIcons.circleQuestionMark), label: 'QUIZ'),
            NavigationDestination(icon: Icon(LucideIcons.chartNoAxesColumn), label: 'STATS'),
          ],
        ),
      ),
    );
  }
}
