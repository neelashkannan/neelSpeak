import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/onboarding/onboarding_flow.dart';
import 'state/settings_provider.dart';
import 'ui/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: NeelSpeakApp()));
}

class NeelSpeakApp extends ConsumerWidget {
  const NeelSpeakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'NeelSpeak',
      debugShowCheckedModeBanner: false,
      theme: NeelSpeakTheme.light(),
      darkTheme: NeelSpeakTheme.dark(),
      themeMode: ThemeMode.system,
      home: settings.setupComplete ? const HomePage() : const OnboardingFlow(),
    );
  }
}
