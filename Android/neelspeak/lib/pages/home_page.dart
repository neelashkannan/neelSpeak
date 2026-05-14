import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings_provider.dart';
import '../ui/premium_widgets.dart';
import 'settings/cleanup_engine_page.dart';
import 'settings/cleanup_mode_page.dart';
import 'settings/test_cleanup_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final status = ref.watch(imeStatusProvider);
    final imeState = status.maybeWhen(
      data: (m) => (m['state'] ?? 'idle').toString(),
      orElse: () => 'idle',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('NeelSpeak')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionIntro(
                      eyebrow: 'Android voice keyboard',
                      title: 'Voice typing that feels native.',
                      subtitle:
                          'Hold the mic pill in any text field, dictate naturally, and let NeelSpeak clean the transcript before it lands.',
                      trailing: InfoPill(
                        label: _imeBadgeLabel(imeState),
                        icon: _imeBadgeIcon(imeState),
                        tint: _imeBadgeColor(context, imeState),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        InfoPill(
                          label: _modeLabel(settings.cleanupMode),
                          icon: Icons.auto_fix_high,
                        ),
                        InfoPill(
                          label: _engineLabel(settings.cleanupEngine),
                          icon: Icons.hub,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    DetailRow(
                      label: 'Keyboard status',
                      value: _imeDetail(imeState),
                      icon: Icons.keyboard_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionIntro(
                eyebrow: 'Tune the experience',
                title: 'Controls and diagnostics',
                subtitle:
                    'Switch cleanup behaviour, choose the model provider, or test the current setup before you start dictating in other apps.',
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.auto_fix_high,
                title: 'Cleanup mode',
                subtitle: _modeLabel(settings.cleanupMode),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CleanupModePage()),
                ),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.cloud_outlined,
                title: 'Cleanup engine',
                subtitle: _engineLabel(settings.cleanupEngine),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CleanupEnginePage()),
                ),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.science_outlined,
                title: 'Test cleanup',
                subtitle:
                    'Run a sample transcript through the configured engine and check latency.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TestCleanupPage()),
                ),
              ),
            ],
          ),
        ),
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

  String _imeBadgeLabel(String state) => switch (state) {
        'recording' => 'Listening',
        'transcribing' => 'Transcribing',
        'cleaning' => 'Cleaning',
        _ => 'Ready',
      };

  String _imeDetail(String state) => switch (state) {
        'recording' => 'NeelSpeak is actively capturing audio from the keyboard.',
        'transcribing' => 'Speech is being turned into text on-device.',
        'cleaning' => 'The transcript is being polished before insertion.',
        _ => 'Open any text field and hold the mic pill to dictate.',
      };

  IconData _imeBadgeIcon(String state) => switch (state) {
        'recording' => Icons.mic,
        'transcribing' => Icons.graphic_eq,
        'cleaning' => Icons.auto_fix_high,
        _ => Icons.check_circle_outline,
      };

  Color _imeBadgeColor(BuildContext context, String state) => switch (state) {
        'recording' => Colors.redAccent,
        'transcribing' => Theme.of(context).colorScheme.primary,
        'cleaning' => Theme.of(context).colorScheme.secondary,
        _ => Colors.green,
      };
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        ],
      ),
    );
  }
}
