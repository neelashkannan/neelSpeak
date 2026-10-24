import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neelspeak/main.dart';
import 'package:neelspeak/platform/channels.dart';
import 'package:neelspeak/state/settings_provider.dart';

void main() {
  testWidgets('shows onboarding when setup is incomplete',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsChannelProvider.overrideWithValue(_FakeSettingsChannel()),
        ],
        child: const NeelSpeakApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to NeelSpeak'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  // A small phone at 200 % text size, in both themes: layouts must scroll or
  // wrap rather than overflow (an overflow fails the test).
  for (final brightness in Brightness.values) {
    testWidgets('onboarding fits at 200% text ($brightness)', (tester) async {
      await _pumpScaled(tester, brightness, _FakeSettingsChannel());
      expect(find.text('Welcome to NeelSpeak'), findsOneWidget);
      await tester.ensureVisible(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Allow microphone access'), findsOneWidget);
    });

    testWidgets('home fits at 200% text ($brightness)', (tester) async {
      await _pumpScaled(
          tester, brightness, _FakeSettingsChannel({'setupComplete': true}));
      await tester.scrollUntilVisible(find.text('Test cleanup'), 200);
      expect(find.text('Cleanup mode'), findsOneWidget);
    });
  }
}

Future<void> _pumpScaled(
  WidgetTester tester,
  Brightness brightness,
  SettingsChannel channel,
) async {
  tester.view.physicalSize = const Size(360, 690);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsChannelProvider.overrideWithValue(channel)],
      child: const NeelSpeakApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSettingsChannel extends SettingsChannel {
  _FakeSettingsChannel([Map<String, Object?> initial = const {}])
      : _values = Map<String, Object?>.from(initial);

  final Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> getAll() async =>
      Map<String, Object?>.from(_values);

  @override
  Future<void> set(String key, Object? value) async {
    _values[key] = value;
  }

  @override
  Future<bool> hasSecure(String key) async => false;

  @override
  Future<void> setSecure(String key, String value) async {}

  @override
  Future<void> clearSecure(String key) async {}
}
