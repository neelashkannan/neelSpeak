import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/app_theme.dart';
import '../../ui/premium_widgets.dart';
import 'anthropic_config_page.dart';
import 'copilot_config_page.dart';
import 'openai_config_page.dart';

/// Which engines have what they need to run. Re-read each time the page is
/// shown, since the config pages change it.
final _credentialsProvider = FutureProvider.autoDispose<Map<String, bool>>((ref) async {
  final ch = ref.watch(settingsChannelProvider);
  final model = ref.watch(modelChannelProvider);
  final results = await Future.wait([
    ch.hasSecure(Keys.cloudOpenAiKey),
    ch.hasSecure(Keys.cloudAnthropicKey),
    ch.hasSecure(Keys.cloudCopilotOAuth),
    model.isLlmInstalled(),
  ]);
  return {
    'openAICompatible': results[0],
    'anthropic': results[1],
    'githubCopilot': results[2],
    'onDeviceLlm': results[3],
  };
});

class CleanupEnginePage extends ConsumerWidget {
  const CleanupEnginePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider).cleanupEngine;
    final notifier = ref.read(settingsProvider.notifier);
    final ready = ref.watch(_credentialsProvider).valueOrNull ?? const {};
    Future<void> open(Widget page) async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      ref.invalidate(_credentialsProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cleanup engine')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: RadioGroup<String>(
            groupValue: selected,
            onChanged: (next) {
              if (next != null) notifier.setCleanupEngine(next);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const SectionIntro(
                  title: 'Who tidies your words?',
                  subtitle:
                      'Cloud engines receive only the transcribed text, never audio. Set up the one you pick with Configure.',
                ),
                const SizedBox(height: 20),
                _Tile(
                  value: 'openAICompatible',
                  ready: ready['openAICompatible'],
                  selected: selected,
                  title: 'OpenAI-compatible',
                  subtitle:
                      'OpenAI, Groq, OpenRouter, GitHub Models, Ollama, and any OpenAI-compatible endpoint.',
                  icon: Icons.cloud_queue_rounded,
                  onSelect: notifier.setCleanupEngine,
                  onConfigure: () => open(const OpenAiConfigPage()),
                ),
                const SizedBox(height: 12),
                _Tile(
                  value: 'anthropic',
                  ready: ready['anthropic'],
                  selected: selected,
                  title: 'Anthropic Claude',
                  subtitle: 'Direct Anthropic API with your x-api-key.',
                  icon: Icons.psychology_alt_outlined,
                  onSelect: notifier.setCleanupEngine,
                  onConfigure: () => open(const AnthropicConfigPage()),
                ),
                const SizedBox(height: 12),
                _Tile(
                  value: 'githubCopilot',
                  ready: ready['githubCopilot'],
                  readyLabel: 'Signed in',
                  missingLabel: 'Not signed in',
                  selected: selected,
                  title: 'GitHub Copilot',
                  subtitle:
                      'OAuth device flow backed by your Copilot subscription and model entitlements.',
                  icon: Icons.lock_open_rounded,
                  onSelect: notifier.setCleanupEngine,
                  onConfigure: () => open(const CopilotConfigPage()),
                ),
                const SizedBox(height: 12),
                _Tile(
                  value: 'onDeviceLlm',
                  selected: selected,
                  title: 'On-device (Gemma 3 1B)',
                  subtitle:
                      'Runs entirely on this phone. Needs the ~530 MB Gemma model on the device (see README) and is slower than the cloud engines.',
                  icon: Icons.memory_rounded,
                  onSelect: notifier.setCleanupEngine,
                  onConfigure: null,
                  ready: ready['onDeviceLlm'],
                  readyLabel: 'Model downloaded',
                  missingLabel: 'Model not downloaded',
                ),
              ],
            ),
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
    this.ready,
    this.readyLabel = 'Key saved',
    this.missingLabel = 'Needs an API key',
  });

  final String value;
  final String selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String> onSelect;
  final VoidCallback? onConfigure;
  final bool? ready;
  final String readyLabel;
  final String missingLabel;

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
                    Radio<String>(value: value),
                  ],
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(170),
                      ),
                ),
                if (ready != null) ...[
                  const SizedBox(height: 12),
                  InfoPill(
                    label: ready! ? readyLabel : missingLabel,
                    icon: ready! ? Icons.check_circle_outline : Icons.info_outline,
                    tint: ready!
                        ? Theme.of(context).colorScheme.success
                        : Theme.of(context).colorScheme.warning,
                  ),
                ],
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
