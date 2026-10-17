import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App settings. Phase 3 persists these with shared_preferences.
class SettingsState {
  final bool ttsEnabled;

  /// Daily reminder time as minutes after midnight (08:00 = 480).
  final int reminderMinutes;

  const SettingsState({this.ttsEnabled = false, this.reminderMinutes = 480});

  SettingsState copyWith({bool? ttsEnabled, int? reminderMinutes}) {
    return SettingsState(
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void toggleTts() => state = state.copyWith(ttsEnabled: !state.ttsEnabled);
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
