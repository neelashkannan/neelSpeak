import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';
import 'model_download_page.dart';
import 'stt_test_page.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _pageCount = 7;
  final _controller = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Android setup',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            'Step ${_page + 1} of $_pageCount',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (_page + 1) / _pageCount,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      _WelcomePage(onNext: _next),
                      _MicPermissionPage(onNext: _next),
                      ModelDownloadPage(onNext: _next),
                      SttTestPage(onNext: _next),
                      _EnableImePage(onNext: _next),
                      _SetDefaultImePage(onNext: _next),
                      _EngineSelectPage(onDone: _finish),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _next() => _controller.nextPage(
      duration: const Duration(milliseconds: 220), curve: Curves.easeOut);

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).markSetupComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _Step(
      title: 'Welcome to NeelSpeak',
      subtitle:
          'NeelSpeak replaces your keyboard. In any text field, hold the mic pill to dictate — release to insert the cleaned transcript. Everything runs on-device by default.',
      icon: Icons.mic_none,
      onPrimary: onNext,
      primaryLabel: 'Get started',
    );
  }
}

class _MicPermissionPage extends StatefulWidget {
  const _MicPermissionPage({required this.onNext});
  final VoidCallback onNext;
  @override
  State<_MicPermissionPage> createState() => _MicPermissionPageState();
}

class _MicPermissionPageState extends State<_MicPermissionPage> {
  bool _granted = false;

  @override
  Widget build(BuildContext context) {
    return _Step(
      title: 'Allow microphone access',
      subtitle:
          'NeelSpeak needs the microphone permission to capture your voice. Audio never leaves your device unless you choose a cloud cleanup engine.',
      icon: Icons.mic,
      onPrimary: () async {
        final status = await Permission.microphone.request();
        if (status.isGranted) {
          setState(() => _granted = true);
          widget.onNext();
        } else if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
      },
      primaryLabel: _granted ? 'Granted' : 'Grant permission',
    );
  }
}

class _EnableImePage extends ConsumerWidget {
  const _EnableImePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Step(
      title: 'Enable NeelSpeak keyboard',
      subtitle:
          'In the system Settings screen that opens next, toggle NeelSpeak under "Manage keyboards", then come back here.',
      icon: Icons.keyboard,
      onPrimary: () async {
        await ref.read(systemChannelProvider).openImeSettings();
        // The user comes back via Back button — they can tap "I enabled it"
        // to advance. We don't auto-advance on resume to avoid surprise.
      },
      primaryLabel: 'Open keyboard settings',
      onSecondary: onNext,
      secondaryLabel: 'I enabled it',
    );
  }
}

class _SetDefaultImePage extends ConsumerWidget {
  const _SetDefaultImePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Step(
      title: 'Set as your keyboard',
      subtitle:
          'Pick NeelSpeak from the keyboard switcher so you can hold to talk in any app.',
      icon: Icons.swap_horiz,
      onPrimary: () => ref.read(systemChannelProvider).showImePicker(),
      primaryLabel: 'Show keyboard switcher',
      onSecondary: onNext,
      secondaryLabel: 'Continue',
    );
  }
}

class _EngineSelectPage extends ConsumerWidget {
  const _EngineSelectPage({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Step(
      title: 'Choose a cleanup engine',
      subtitle:
          'NeelSpeak can polish your transcript through one of four engines. You can change this later in Settings.',
      icon: Icons.tune,
      onPrimary: onDone,
      primaryLabel: 'Finish',
      onSecondary: onDone,
      secondaryLabel: 'Skip — no cleanup',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EngineCard(
              label: 'OpenAI-compatible',
              subtitle: 'OpenAI, Groq, OpenRouter, Ollama. ~300ms.',
              value: 'openAICompatible'),
          _EngineCard(
              label: 'Anthropic Claude',
              subtitle: 'Direct /v1/messages. ~250ms.',
              value: 'anthropic'),
          _EngineCard(
              label: 'GitHub Copilot',
              subtitle: 'OAuth sign-in. ~300ms.',
              value: 'githubCopilot'),
          _EngineCard(
              label: 'On-device (Gemma)',
              subtitle: 'MediaPipe + Gemma 3 1B. Slower, fully offline.',
              value: 'onDeviceLlm'),
        ],
      ),
    );
  }
}

class _EngineCard extends ConsumerWidget {
  const _EngineCard(
      {required this.label, required this.subtitle, required this.value});
  final String label;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider).cleanupEngine == value;
    return GlassPanel(
      onTap: () => ref.read(settingsProvider.notifier).setCleanupEngine(value),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
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
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPrimary,
    required this.primaryLabel,
    this.onSecondary,
    this.secondaryLabel,
    this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(22),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                if (child != null) ...[
                  const SizedBox(height: 24),
                  child!,
                ],
                const SizedBox(height: 28),
                _ActionButtons(
                  onPrimary: onPrimary,
                  primaryLabel: primaryLabel,
                  onSecondary: onSecondary,
                  secondaryLabel: secondaryLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onPrimary,
    required this.primaryLabel,
    this.onSecondary,
    this.secondaryLabel,
  });

  final VoidCallback onPrimary;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onSecondary != null && secondaryLabel != null) ...[
                OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: onPrimary,
                child: Text(primaryLabel),
              ),
            ],
          );
        }

        return Row(
          children: [
            if (onSecondary != null && secondaryLabel != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ),
            if (onSecondary != null && secondaryLabel != null)
              const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onPrimary,
                child: Text(primaryLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}
