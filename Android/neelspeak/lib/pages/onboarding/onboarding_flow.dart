import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../state/settings_provider.dart';
import '../../ui/app_theme.dart';
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xl),
              child: Column(
                children: [
                  GlassPanel(
                    padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.xl, Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (_page > 0)
                              IconButton(
                                onPressed: _back,
                                tooltip: 'Back',
                                icon: const Icon(Icons.arrow_back_rounded),
                              )
                            else
                              const SizedBox(width: Space.md),
                            Expanded(
                              child: Wrap(
                                spacing: Space.md,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Set up NeelSpeak',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Step ${_page + 1} of $_pageCount',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Padding(
                          padding: const EdgeInsets.only(left: Space.md),
                          child: LinearProgressIndicator(
                            value: (_page + 1) / _pageCount,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                            semanticsLabel: 'Setup progress',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
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
      ),
    );
  }

  void _next() => _controller.nextPage(
      duration: const Duration(milliseconds: 220), curve: Curves.easeOut);

  void _back() => _controller.previousPage(
      duration: const Duration(milliseconds: 220), curve: Curves.easeOut);

  Future<void> _finish({required bool withCleanup}) async {
    final notifier = ref.read(settingsProvider.notifier);
    final mode = ref.read(settingsProvider).cleanupMode;
    if (!withCleanup) {
      await notifier.setCleanupMode('off');
    } else if (mode == 'off') {
      // Picking an engine means the user wants cleanup on.
      await notifier.setCleanupMode('conservative');
    }
    await notifier.markSetupComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }
}

/// Re-runs [onResume] whenever the app returns to the foreground, e.g. after
/// the user changed something in system Settings.
mixin _ResumeCheck<T extends StatefulWidget> on State<T> {
  late final AppLifecycleListener _lifecycle;

  void onResume();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: onResume);
    onResume();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
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
          'NeelSpeak is a voice keyboard. In any text field, hold the mic button and talk — let go and your words are typed for you. Speech is turned into text on this phone.',
      icon: Icons.mic_none,
      showBrandLogo: true,
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

class _MicPermissionPageState extends State<_MicPermissionPage>
    with _ResumeCheck {
  PermissionStatus? _status;
  bool _asked = false;

  @override
  Future<void> onResume() async {
    final status = await Permission.microphone.status;
    if (mounted) setState(() => _status = status);
  }

  Future<void> _request() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    setState(() {
      _status = status;
      _asked = true;
    });
    if (status.isGranted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final granted = _status?.isGranted ?? false;
    final blocked = _status?.isPermanentlyDenied ?? false;
    final denied = _status?.isDenied ?? false;
    return _Step(
      title: 'Allow microphone access',
      subtitle:
          'NeelSpeak only listens while you hold the mic button. Recordings are transcribed on this phone and never stored.',
      icon: Icons.mic,
      onPrimary: granted
          ? widget.onNext
          : blocked
              ? openAppSettings
              : _request,
      primaryLabel: granted
          ? 'Continue'
          : blocked
              ? 'Open app settings'
              : 'Allow microphone',
      child: granted
          ? const StatusBanner(
              tone: StatusTone.success,
              message: 'Microphone access is on.',
            )
          : blocked
              ? const StatusBanner(
                  tone: StatusTone.warning,
                  message:
                      'Microphone access is turned off for NeelSpeak. Open app settings, tap Permissions → Microphone, and choose “Allow only while using the app”.',
                )
              : denied && _asked
                  ? const StatusBanner(
                      tone: StatusTone.warning,
                      message:
                          'NeelSpeak can’t type what you say without the microphone. Tap the button to allow it.',
                    )
                  : null,
    );
  }
}

class _EnableImePage extends ConsumerStatefulWidget {
  const _EnableImePage({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_EnableImePage> createState() => _EnableImePageState();
}

class _EnableImePageState extends ConsumerState<_EnableImePage>
    with _ResumeCheck {
  bool _enabled = false;

  @override
  Future<void> onResume() async {
    final enabled = await ref.read(systemChannelProvider).isEnabledIme();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return _Step(
      title: 'Turn on the NeelSpeak keyboard',
      subtitle:
          'Android asks you to switch new keyboards on yourself. In the screen that opens, turn on NeelSpeak, then come back here.',
      icon: Icons.keyboard,
      onPrimary: _enabled
          ? widget.onNext
          : () => ref.read(systemChannelProvider).openImeSettings(),
      primaryLabel: _enabled ? 'Continue' : 'Open keyboard settings',
      onSecondary: _enabled ? null : widget.onNext,
      secondaryLabel: _enabled ? null : 'Skip for now',
      child: _enabled
          ? const StatusBanner(
              tone: StatusTone.success,
              message: 'NeelSpeak keyboard is on.',
            )
          : const StatusBanner(
              tone: StatusTone.info,
              message:
                  'Android shows a standard warning that keyboards can collect what you type. NeelSpeak only types what you dictate; it doesn’t read or store anything else you type.',
            ),
    );
  }
}

class _SetDefaultImePage extends ConsumerStatefulWidget {
  const _SetDefaultImePage({required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<_SetDefaultImePage> createState() => _SetDefaultImePageState();
}

class _SetDefaultImePageState extends ConsumerState<_SetDefaultImePage>
    with _ResumeCheck {
  bool _selected = false;

  @override
  Future<void> onResume() async {
    final selected = await ref.read(systemChannelProvider).isDefaultIme();
    if (mounted) setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) {
    return _Step(
      title: 'Switch to NeelSpeak',
      subtitle:
          'Pick NeelSpeak in the keyboard switcher. Later, tap the keyboard icon in the navigation bar (or the arrow on the NeelSpeak keyboard) to swap back and forth.',
      icon: Icons.swap_horiz,
      onPrimary: _selected
          ? widget.onNext
          : () async {
              await ref.read(systemChannelProvider).showImePicker();
            },
      primaryLabel: _selected ? 'Continue' : 'Choose keyboard',
      onSecondary: _selected ? null : widget.onNext,
      secondaryLabel: _selected ? null : 'Skip for now',
      child: _selected
          ? const StatusBanner(
              tone: StatusTone.success,
              message: 'NeelSpeak is your current keyboard.',
            )
          : null,
    );
  }
}

class _EngineSelectPage extends ConsumerWidget {
  const _EngineSelectPage({required this.onDone});
  final Future<void> Function({required bool withCleanup}) onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Step(
      title: 'Tidy up your words (optional)',
      subtitle:
          'NeelSpeak can remove “um”s, repeats and false starts with an AI model. Pick a provider now and add its key later under Cleanup engine — or skip and type exactly what you said.',
      icon: Icons.auto_fix_high_rounded,
      onPrimary: () => onDone(withCleanup: true),
      primaryLabel: 'Use this engine',
      onSecondary: () => onDone(withCleanup: false),
      secondaryLabel: 'Skip — no cleanup',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EngineCard(
              label: 'OpenAI-compatible',
              subtitle: 'OpenAI, GitHub Models, Groq, OpenRouter, Ollama or OpenCode.',
              value: 'openAICompatible'),
          SizedBox(height: Space.md),
          _EngineCard(
              label: 'Anthropic Claude',
              subtitle: 'Your Anthropic API key. Fast and accurate.',
              value: 'anthropic'),
          SizedBox(height: Space.md),
          _EngineCard(
              label: 'GitHub Copilot',
              subtitle: 'Sign in with GitHub; uses your Copilot plan.',
              value: 'githubCopilot'),
          SizedBox(height: Space.md),
          _EngineCard(
              label: 'On-device (Gemma)',
              subtitle: 'Fully offline after a large download. Slower.',
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
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: GlassPanel(
        onTap: () => ref.read(settingsProvider.notifier).setCleanupEngine(value),
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Space.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(170),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            ExcludeSemantics(
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ],
        ),
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
    this.showBrandLogo = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final Widget? child;
  final bool showBrandLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBrandLogo)
                  const BrandLogo(size: 80)
                else
                  StepIcon(icon: icon),
                const SizedBox(height: Space.xxl),
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.headlineSmall),
                ),
                const SizedBox(height: Space.md),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                if (child != null) ...[
                  const SizedBox(height: Space.xxl),
                  child!,
                ],
                const SizedBox(height: Space.section),
                ActionButtons(
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
