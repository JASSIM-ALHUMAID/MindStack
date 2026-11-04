import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/failures.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// Preferences saved separately from the study database.
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
  SharedPreferences? _preferences;
  Future<void> _pending = Future<void>.value();

  @override
  SettingsState build() => const SettingsState();

  /// Called at startup before the app opens.
  void load(SharedPreferences preferences) {
    _preferences = preferences;
    final tts = preferences.get('ttsEnabled');
    final reminder = preferences.get('reminderMinutes');
    state = SettingsState(
      ttsEnabled: tts is bool ? tts : false,
      reminderMinutes: reminder is int && reminder >= 0 && reminder < 1440
          ? reminder
          : 480,
    );
  }

  Future<void> setTts(bool enabled) => _update(
    (current) => current.copyWith(ttsEnabled: enabled),
    (preferences, next) => preferences.setBool('ttsEnabled', next.ttsEnabled),
  );

  Future<void> toggleTts() => _update(
    (current) => current.copyWith(ttsEnabled: !current.ttsEnabled),
    (preferences, next) => preferences.setBool('ttsEnabled', next.ttsEnabled),
  );

  Future<void> setReminderMinutes(int minutes) async {
    if (minutes < 0 || minutes >= 1440) {
      throw const InvalidInput(
        field: 'reminderMinutes',
        reason: 'Choose a time between 00:00 and 23:59.',
      );
    }
    await _update(
      (current) => current.copyWith(reminderMinutes: minutes),
      (preferences, next) =>
          preferences.setInt('reminderMinutes', next.reminderMinutes),
    );
  }

  Future<void> _update(
    SettingsState Function(SettingsState) change,
    Future<bool> Function(SharedPreferences, SettingsState) save,
  ) {
    // Serialize writes so rapid toggles use the preceding saved state.
    final write = _pending.then((_) async {
      try {
        if (_preferences == null) {
          load(await ref.read(sharedPreferencesProvider.future));
        }
        final next = change(state);
        if (!await save(_preferences!, next)) {
          throw StateError('Preference write was rejected');
        }
        state = next;
      } on AppFailure {
        rethrow;
      } on Object catch (error, stack) {
        Error.throwWithStackTrace(StorageFailure(error, stack), stack);
      }
    });
    // A failed write must not prevent a later retry.
    _pending = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return write;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
