import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the selected bottom-navigation tab.
/// 0 Inbox, 1 Library, 2 Review, 3 Quiz, 4 Stats.
/// Shared so that other screens (Deck Editor, Stats, Quiz results)
/// can send the user to the Review tab.
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void set(int index) => state = index;
}

final tabIndexProvider =
    NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);
