import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';
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
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SectionIntro(
                eyebrow: 'Provider selection',
                title: 'Pick the cleanup engine that matches your workflow.',
                subtitle:
                    'Switch between cloud providers and on-device processing. Provider-specific credentials live behind each engine card.',
              ),
              const SizedBox(height: 20),
              _Tile(
                value: 'openAICompatible',
                selected: selected,
                title: 'OpenAI-compatible',
                subtitle:
                    'OpenAI, Groq, OpenRouter, GitHub Models, Ollama, and any OpenAI-compatible endpoint.',
                icon: Icons.cloud_queue_rounded,
                onSelect: notifier.setCleanupEngine,
                onConfigure: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OpenAiConfigPage()),
                ),
              ),
              const SizedBox(height: 12),
              _Tile(
                value: 'anthropic',
                selected: selected,
                title: 'Anthropic Claude',
                subtitle: 'Direct Anthropic API with your x-api-key.',
                icon: Icons.psychology_alt_outlined,
                onSelect: notifier.setCleanupEngine,
                onConfigure: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnthropicConfigPage()),
                ),
              ),
              const SizedBox(height: 12),
              _Tile(
                value: 'githubCopilot',
                selected: selected,
                title: 'GitHub Copilot',
                subtitle:
                    'OAuth device flow backed by your Copilot subscription and model entitlements.',
                icon: Icons.lock_open_rounded,
                onSelect: notifier.setCleanupEngine,
                onConfigure: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CopilotConfigPage()),
                ),
              ),
              const SizedBox(height: 12),
              _Tile(
                value: 'onDeviceLlm',
                selected: selected,
                title: 'On-device (Gemma 3 1B int4)',
                subtitle:
                    'MediaPipe LLM inference with no network dependency after the initial download.',
                icon: Icons.memory_rounded,
                onSelect: notifier.setCleanupEngine,
                onConfigure: null,
              ),
            ],
          ),
        ),
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
    required this.icon,
    required this.onSelect,
    required this.onConfigure,
  });

  final String value;
  final String selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String> onSelect;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final tint = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withAlpha(150);

    return GlassPanel(
      onTap: () => onSelect(value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: tint.withAlpha(20),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: tint),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Radio<String>(
                      value: value,
                      groupValue: selected,
                      onChanged: (next) {
                        if (next != null) onSelect(next);
                      },
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(170),
                  ),
                ),
                if (onConfigure != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onConfigure,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configure'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
