import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';

class CleanupModePage extends ConsumerWidget {
  const CleanupModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider).cleanupMode;
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Cleanup mode')),
      body: ListView(
        children: [
          _option('off', 'Off', 'Type exactly what was said.', selected, notifier),
          _option('conservative', 'Conservative',
              'Strip fillers, stutters, repetitions, and course corrections.', selected, notifier),
          _option('aggressive', 'Aggressive',
              'Also tighten phrasing and fix obvious spoken-word slips.', selected, notifier),
        ],
      ),
    );
  }

  Widget _option(String value, String title, String subtitle, String selected, SettingsNotifier n) =>
      RadioListTile<String>(
        value: value,
        groupValue: selected,
        onChanged: (v) { if (v != null) n.setCleanupMode(v); },
        title: Text(title),
        subtitle: Text(subtitle),
      );
}
