import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/onboarding/onboarding_flow.dart';
import 'state/settings_provider.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3366FF),
      ),
      home: settings.setupComplete ? const HomePage() : const OnboardingFlow(),
    );
  }
}
