import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindstack/application/settings.dart';
import 'package:mindstack/application/startup.dart';
import 'package:mindstack/domain/failures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/container.dart';

Future<ProviderContainer> _openSettings() async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final preferences = await container.read(sharedPreferencesProvider.future);
  container.read(settingsProvider.notifier).load(preferences);
  return container;
}

class _SwitchPreferences extends Fake implements SharedPreferences {
  bool fail = true;
  final Map<String, Object> values = {};

  @override
  Object? get(String key) => values[key];

  @override
  Future<bool> setBool(String key, bool value) async {
    if (fail) return false;
    values[key] = value;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing preferences use TTS off and 08:00 defaults', () async {
    final container = await _openSettings();
    final state = container.read(settingsProvider);

    expect(state.ttsEnabled, isFalse);
    expect(state.reminderMinutes, 480);
  });

  test('ttsEnabled survives a new ProviderContainer', () async {
    final first = await _openSettings();
    await first.read(settingsProvider.notifier).setTts(true);
    first.dispose();

    final second = await _openSettings();
    expect(second.read(settingsProvider).ttsEnabled, isTrue);
    await second.read(settingsProvider.notifier).setTts(false);
    final third = await _openSettings();
    expect(third.read(settingsProvider).ttsEnabled, isFalse);
  });

  test('reminder time survives a new ProviderContainer', () async {
    final first = await _openSettings();
    await first.read(settingsProvider.notifier).setReminderMinutes(1110);
    first.dispose();

    final second = await _openSettings();
    expect(second.read(settingsProvider).reminderMinutes, 1110);
  });

  test(
    'invalid reminder times are rejected without changing the saved value',
    () async {
      final container = await _openSettings();
      final settings = container.read(settingsProvider.notifier);
      await settings.setReminderMinutes(600);

      for (final invalid in [-1, 1440]) {
        await expectLater(
          settings.setReminderMinutes(invalid),
          throwsA(isA<InvalidInput>()),
        );
      }

      expect(container.read(settingsProvider).reminderMinutes, 600);
      final reopened = await _openSettings();
      expect(reopened.read(settingsProvider).reminderMinutes, 600);
    },
  );

  test('two rapid toggles persist off without losing either update', () async {
    final container = await _openSettings();
    final settings = container.read(settingsProvider.notifier);

    await Future.wait([settings.toggleTts(), settings.toggleTts()]);

    expect(container.read(settingsProvider).ttsEnabled, isFalse);
    final preferences = await container.read(sharedPreferencesProvider.future);
    expect(preferences.getBool('ttsEnabled'), isFalse);
  });

  test('a failed save preserves state and does not block a retry', () async {
    final preferences = _SwitchPreferences();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => preferences),
      ],
    );
    addTearDown(container.dispose);
    final settings = container.read(settingsProvider.notifier);
    settings.load(preferences);

    await expectLater(settings.setTts(true), throwsA(isA<StorageFailure>()));
    expect(container.read(settingsProvider).ttsEnabled, isFalse);

    preferences.fail = false;
    await settings.setTts(true);
    expect(container.read(settingsProvider).ttsEnabled, isTrue);
    expect(preferences.get('ttsEnabled'), isTrue);
  });

  test(
    'wrong types and out-of-range stored values fall back to defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        'ttsEnabled': 'invalid',
        'reminderMinutes': 2000,
      });
      final container = await _openSettings();

      expect(container.read(settingsProvider).ttsEnabled, isFalse);
      expect(container.read(settingsProvider).reminderMinutes, 480);
    },
  );

  test('app startup loads saved settings before completing', () async {
    final container = makeContainer(
      initialPreferences: {'ttsEnabled': true, 'reminderMinutes': 1110},
    );

    await container.read(appStartupProvider.future);

    expect(container.read(settingsProvider).ttsEnabled, isTrue);
    expect(container.read(settingsProvider).reminderMinutes, 1110);
  });
}
