import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../state/settings_provider.dart';
import '../ui/app_theme.dart';
import '../ui/premium_widgets.dart';
import 'onboarding/model_download_page.dart';
import 'settings/cleanup_engine_page.dart';
import 'settings/cleanup_mode_page.dart';
import 'settings/test_cleanup_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // System settings (keyboard, permissions) change outside the app, and the
    // keyboard writes cleanup errors while we're in the background.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(setupStatusProvider);
    ref.read(settingsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final setup = ref.watch(setupStatusProvider);
    final status = ref.watch(imeStatusProvider);
    final imeState = status.maybeWhen(
      data: (m) => (m['state'] ?? 'idle').toString(),
      orElse: () => 'idle',
    );
    // A dictation just finished: its cleanup may have failed.
    ref.listen(imeStatusProvider, (prev, next) {
      final was = prev?.valueOrNull?['state'];
      final now = next.valueOrNull?['state'];
      if (was == 'cleaning' && now != 'cleaning') {
        ref.read(settingsProvider.notifier).refresh();
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Space.page,
        title: Row(
          children: [
            const BrandLogo(size: 32, withGlow: false),
            const SizedBox(width: Space.md),
            Flexible(
              child: Text(
                'NeelSpeak',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxl),
              children: [
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoPill(
                        label: _imeBadgeLabel(imeState, setup.valueOrNull),
                        icon: _imeBadgeIcon(imeState, setup.valueOrNull),
                        tint: _imeBadgeColor(context, imeState, setup.valueOrNull),
                      ),
                      const SizedBox(height: Space.lg),
                      const SectionIntro(
                        eyebrow: 'Voice keyboard',
                        title: 'Hold, speak, let go.',
                        subtitle:
                            'In any text field, hold the mic button on the NeelSpeak keyboard and talk. Let go and your words are typed — slide your finger off the button to cancel.',
                      ),
                      const SizedBox(height: Space.xl),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        children: [
                          InfoPill(
                            label: _modeShort(settings.cleanupMode),
                            icon: Icons.auto_fix_high,
                          ),
                          if (settings.cleanupMode != 'off')
                            InfoPill(
                              label: _engineLabel(settings.cleanupEngine),
                              icon: Icons.hub,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                ...switch (setup) {
                  AsyncData(:final value) when !value.complete => [
                      const SizedBox(height: Space.xl),
                      _SetupChecklist(status: value, onChanged: _refresh),
                    ],
                  AsyncError() => [
                      const SizedBox(height: Space.xl),
                      const StatusBanner(
                        tone: StatusTone.warning,
                        message: 'Couldn’t check the keyboard setup. Pull down to try again.',
                      ),
                    ],
                  _ => const <Widget>[],
                },
                if (settings.lastCleanupError != null && settings.cleanupMode != 'off') ...[
                  const SizedBox(height: Space.xl),
                  StatusBanner(
                    tone: StatusTone.warning,
                    title: 'Last cleanup didn’t work',
                    message:
                        '${settings.lastCleanupError!}\nYour words were typed without cleanup${_when(settings.lastCleanupErrorAt)}.',
                    action: Wrap(
                      spacing: Space.sm,
                      children: [
                        TextButton(
                          onPressed: () => _push(const CleanupEnginePage()),
                          child: const Text('Check engine settings'),
                        ),
                        TextButton(
                          onPressed: () => _push(const TestCleanupPage()),
                          child: const Text('Run a test'),
                        ),
                      ],
                    ),
                    onDismiss: () =>
                        ref.read(settingsProvider.notifier).clearCleanupError(),
                  ),
                ],
                const SizedBox(height: Space.section),
                const SectionIntro(
                  title: 'Settings',
                  subtitle:
                      'Choose how much tidying NeelSpeak does and which AI provider does it.',
                ),
                const SizedBox(height: Space.lg),
                _ActionTile(
                  icon: Icons.auto_fix_high,
                  title: 'Cleanup mode',
                  subtitle: _modeLabel(settings.cleanupMode),
                  onTap: () => _push(const CleanupModePage()),
                ),
                const SizedBox(height: Space.md),
                _ActionTile(
                  icon: Icons.cloud_outlined,
                  title: 'Cleanup engine',
                  subtitle: _engineLabel(settings.cleanupEngine),
                  onTap: () => _push(const CleanupEnginePage()),
                ),
                const SizedBox(height: Space.md),
                _ActionTile(
                  icon: Icons.science_outlined,
                  title: 'Test cleanup',
                  subtitle: 'Send a sample sentence through your engine and see the result.',
                  onTap: () => _push(const TestCleanupPage()),
                ),
                const SizedBox(height: Space.section),
                const _PrivacyFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) => _refresh());

  String _when(DateTime? at) {
    if (at == null) return '';
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return ' just now';
    if (ago.inHours < 1) return ' ${ago.inMinutes} min ago';
    if (ago.inDays < 1) return ' ${ago.inHours} h ago';
    return ' ${ago.inDays} d ago';
  }

  String _modeShort(String raw) => switch (raw) {
        'conservative' => 'Cleanup: light',
        'aggressive' => 'Cleanup: thorough',
        _ => 'Cleanup off',
      };

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

  String _imeBadgeLabel(String state, SetupStatus? setup) => switch (state) {
        'recording' => 'Listening',
        'transcribing' => 'Transcribing',
        'cleaning' => 'Cleaning up',
        'error' => 'Needs attention',
        _ when setup != null && !setup.complete => 'Setup incomplete',
        _ => 'Ready',
      };

  IconData _imeBadgeIcon(String state, SetupStatus? setup) => switch (state) {
        'recording' => Icons.mic,
        'transcribing' => Icons.graphic_eq,
        'cleaning' => Icons.auto_fix_high,
        'error' => Icons.error_outline,
        _ when setup != null && !setup.complete => Icons.pending_outlined,
        _ => Icons.check_circle_outline,
      };

  Color _imeBadgeColor(BuildContext context, String state, SetupStatus? setup) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state) {
      'recording' => scheme.error,
      'transcribing' => scheme.primary,
      'cleaning' => scheme.secondary,
      'error' => scheme.error,
      _ when setup != null && !setup.complete => scheme.warning,
      _ => scheme.success,
    };
  }
}

/// The steps still missing before the keyboard can type, each with the one
/// action that fixes it.
class _SetupChecklist extends ConsumerWidget {
  const _SetupChecklist({required this.status, required this.onChanged});

  final SetupStatus status;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system = ref.read(systemChannelProvider);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Finish setting up', style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'NeelSpeak can’t type for you until these are done.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Space.lg),
          _CheckRow(
            done: status.micGranted,
            label: 'Microphone access',
            actionLabel: status.micPermanentlyDenied ? 'Open settings' : 'Allow',
            onAction: () async {
              if (status.micPermanentlyDenied) {
                await openAppSettings();
              } else {
                await Permission.microphone.request();
              }
              onChanged();
            },
          ),
          _CheckRow(
            done: status.modelInstalled,
            label: 'Speech model',
            actionLabel: 'Download',
            onAction: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _ModelDownloadScreen()),
              );
              onChanged();
            },
          ),
          _CheckRow(
            done: status.imeEnabled,
            label: 'NeelSpeak keyboard turned on',
            actionLabel: 'Turn on',
            onAction: system.openImeSettings,
          ),
          _CheckRow(
            done: status.imeSelected,
            label: 'NeelSpeak chosen as keyboard',
            actionLabel: 'Choose',
            onAction: status.imeEnabled ? system.showImePicker : null,
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.done,
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  final bool done;
  final String label;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: done ? scheme.success : scheme.onSurface.withAlpha(120),
              semanticLabel: done ? 'Done' : 'Not done',
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            if (!done)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ModelDownloadScreen extends StatelessWidget {
  const _ModelDownloadScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech model')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            child: ModelDownloadPage(
              inOnboarding: false,
              onNext: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyFooter extends ConsumerWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider).valueOrNull;
    final muted = theme.colorScheme.onSurface.withAlpha(150);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: muted),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                'Your voice is transcribed on this phone and is never saved or uploaded. '
                'If cleanup is on, only the transcribed text is sent to the provider you chose. '
                'API keys are stored encrypted on this device and aren’t included in backups.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
        if (version != null && version.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text(
            'NeelSpeak $version',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
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
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            StepIcon(icon: icon, size: 52),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
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
            const ExcludeSemantics(
              child: Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
