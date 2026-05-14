import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';

class CleanupModePage extends ConsumerWidget {
  const CleanupModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider).cleanupMode;
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Cleanup mode')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SectionIntro(
                eyebrow: 'Transcript behavior',
                title: 'Choose how much cleanup to apply.',
                subtitle:
                    'Pick the amount of post-processing NeelSpeak should do before it inserts text into the active app.',
              ),
              const SizedBox(height: 20),
              _ModeOption(
                value: 'off',
                title: 'Off',
                subtitle: 'Type exactly what was said with no polishing.',
                icon: Icons.mic_none_rounded,
                selected: selected,
                onSelect: notifier.setCleanupMode,
              ),
              const SizedBox(height: 12),
              _ModeOption(
                value: 'conservative',
                title: 'Conservative',
                subtitle:
                    'Remove fillers, stutters, repetitions, and course corrections while keeping your wording intact.',
                icon: Icons.auto_fix_high_rounded,
                selected: selected,
                onSelect: notifier.setCleanupMode,
              ),
              const SizedBox(height: 12),
              _ModeOption(
                value: 'aggressive',
                title: 'Aggressive',
                subtitle:
                    'Also tighten phrasing and fix obvious spoken-word slips for a more polished final result.',
                icon: Icons.bolt_rounded,
                selected: selected,
                onSelect: notifier.setCleanupMode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onSelect,
  });

  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final tint = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withAlpha(150);

    return GlassPanel(
      onTap: () => onSelect(value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
