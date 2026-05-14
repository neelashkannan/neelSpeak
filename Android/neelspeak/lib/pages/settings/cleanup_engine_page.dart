import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import 'anthropic_config_page.dart';
import 'copilot_config_page.dart';
import 'openai_config_page.dart';

class CleanupEnginePage extends ConsumerWidget {
  const CleanupEnginePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider).cleanupEngine;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Cleanup engine')),
      body: ListView(
        children: [
          _Tile(
            value: 'openAICompatible',
            selected: selected,
            title: 'OpenAI-compatible',
            subtitle: 'OpenAI, Groq, OpenRouter, Ollama. Configure base URL + API key.',
            onSelect: notifier.setCleanupEngine,
            onConfigure: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OpenAiConfigPage()),
            ),
          ),
          _Tile(
            value: 'anthropic',
            selected: selected,
            title: 'Anthropic Claude',
            subtitle: 'Direct API. Requires x-api-key.',
            onSelect: notifier.setCleanupEngine,
            onConfigure: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnthropicConfigPage()),
            ),
          ),
          _Tile(
            value: 'githubCopilot',
            selected: selected,
            title: 'GitHub Copilot',
            subtitle: 'OAuth device flow. Uses your Copilot subscription.',
            onSelect: notifier.setCleanupEngine,
            onConfigure: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CopilotConfigPage()),
            ),
          ),
          _Tile(
            value: 'onDeviceLlm',
            selected: selected,
            title: 'On-device (Gemma 3 1B int4)',
            subtitle: 'MediaPipe LLM Inference. ~530 MB download, fully offline.',
            onSelect: notifier.setCleanupEngine,
            onConfigure: null,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onSelect,
    required this.onConfigure,
  });

  final String value;
  final String selected;
  final String title;
  final String subtitle;
  final ValueChanged<String> onSelect;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Card(
      child: ListTile(
        leading: Radio<String>(
          value: value,
          groupValue: selected,
          onChanged: (v) { if (v != null) onSelect(v); },
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onConfigure == null
            ? null
            : IconButton(icon: const Icon(Icons.settings), onPressed: onConfigure),
        onTap: () => onSelect(value),
        selected: isSelected,
      ),
    );
  }
}
