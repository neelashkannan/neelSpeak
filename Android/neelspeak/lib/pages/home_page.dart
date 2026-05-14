import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings_provider.dart';
import 'settings/cleanup_engine_page.dart';
import 'settings/cleanup_mode_page.dart';
import 'settings/test_cleanup_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final status = ref.watch(imeStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('NeelSpeak')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.keyboard_voice),
              title: const Text('NeelSpeak keyboard'),
              subtitle: Text(
                status.maybeWhen(
                  data: (m) => 'State: ${m['state']}',
                  orElse: () => 'Hold the mic pill in any text field to dictate.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('Cleanup mode'),
              subtitle: Text(_modeLabel(settings.cleanupMode)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CleanupModePage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('Cleanup engine'),
              subtitle: Text(_engineLabel(settings.cleanupEngine)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CleanupEnginePage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Test cleanup'),
              subtitle: const Text('Run a canned transcript through the configured engine'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TestCleanupPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(String raw) => switch (raw) {
        'off' => 'Off — type exactly what was said',
        'conservative' => 'Conservative — strip fillers and stutters',
        'aggressive' => 'Aggressive — also tighten phrasing',
        _ => raw,
      };

  String _engineLabel(String raw) => switch (raw) {
        'openAICompatible' => 'OpenAI-compatible',
        'anthropic' => 'Anthropic Claude',
        'githubCopilot' => 'GitHub Copilot',
        'onDeviceLlm' => 'On-device (Gemma)',
        _ => raw,
      };
}
