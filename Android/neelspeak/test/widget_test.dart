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
}

class _FakeSettingsChannel extends SettingsChannel {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<Map<String, Object?>> getAll() async =>
      Map<String, Object?>.from(_values);

  @override
  Future<void> set(String key, Object? value) async {
    _values[key] = value;
  }

  @override
  Future<String?> getSecure(String key) async => null;

  @override
  Future<void> setSecure(String key, String value) async {}

  @override
  Future<void> clearSecure(String key) async {}
}
