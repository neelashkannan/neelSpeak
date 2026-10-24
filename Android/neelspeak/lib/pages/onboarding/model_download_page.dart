import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/app_theme.dart';
import '../../ui/premium_widgets.dart';

/// Downloads the Parakeet speech model. Used as an onboarding step and, with
/// [inOnboarding] false, as a standalone screen from Home.
class ModelDownloadPage extends ConsumerStatefulWidget {
  const ModelDownloadPage({
    super.key,
    required this.onNext,
    this.inOnboarding = true,
  });
  final VoidCallback onNext;
  final bool inOnboarding;

  @override
  ConsumerState<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends ConsumerState<ModelDownloadPage> {
  bool _started = false;
  bool _done = false;
  bool _paused = false;
  String _phase = 'idle';
  int _bytes = 0;
  int _total = 0;
  int _extractedFiles = 0;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    final model = ref.read(modelChannelProvider);
    final installed = await model.isParakeetInstalled();
    if (!mounted) return;
    if (installed) {
      setState(() {
        _done = true;
        _phase = 'done';
      });
      return;
    }
    // A download started earlier (e.g. before leaving this screen) is still
    // running natively: pick its progress back up.
    if (await model.isDownloading() && mounted) {
      setState(() => _started = true);
      _listen();
    }
  }

  void _listen() {
    _sub?.cancel();
    _sub = ref.read(modelChannelProvider).progress().listen((event) {
      if (!mounted) return;
      setState(() {
        _phase = (event['phase'] as String?) ?? 'idle';
        if (_phase == 'downloading') {
          _bytes = (event['bytesRead'] as num?)?.toInt() ?? _bytes;
          _total = (event['totalBytes'] as num?)?.toInt() ?? _total;
        } else if (_phase == 'extracting') {
          _extractedFiles =
              (event['files'] as num?)?.toInt() ?? _extractedFiles;
        } else if (_phase == 'done') {
          _done = true;
          _sub?.cancel();
          ref.invalidate(setupStatusProvider);
        } else if (_phase == 'failed') {
          _error = event['message'] as String?;
          _started = false;
          _sub?.cancel();
        } else if (_phase == 'cancelled') {
          _paused = true;
          _started = false;
          _sub?.cancel();
        }
      });
    });
  }

  Future<void> _start() async {
    setState(() {
      _started = true;
      _paused = false;
      _phase = 'starting';
      _extractedFiles = 0;
      _error = null;
    });
    _listen();
    try {
      await ref.read(modelChannelProvider).downloadParakeet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not start the download. Check your connection and try again.';
        _started = false;
      });
    }
  }

  Future<void> _cancel() async {
    await ref.read(modelChannelProvider).cancelDownload();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = _total > 0 ? _bytes / _total : null;
    final mb = (_bytes / 1024 / 1024).toStringAsFixed(0);
    final totalMb =
        _total > 0 ? (_total / 1024 / 1024).toStringAsFixed(0) : '460';
    final busy = _started && !_done && _error == null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StepIcon(icon: Icons.download_for_offline_rounded),
                const SizedBox(height: Space.xl),
                Text(
                  'Download the speech model',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: Space.md),
                Text(
                  'NeelSpeak turns speech into text on this phone with NVIDIA Parakeet, so your voice never leaves the device. The model is a one-time download of about 460 MB — Wi-Fi recommended. If it stops, you can pick up where it left off.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: Space.lg),
                const Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    InfoPill(
                      label: 'Runs offline',
                      icon: Icons.memory_rounded,
                    ),
                    InfoPill(
                      label: '460 MB download',
                      icon: Icons.storage_rounded,
                    ),
                  ],
                ),
                if (busy) ...[
                  const SizedBox(height: Space.xl),
                  Semantics(
                    liveRegion: true,
                    child: _ProgressBlock(
                      value: _phase == 'downloading' ? pct : null,
                      label: switch (_phase) {
                        'downloading' => pct != null
                            ? '$mb of $totalMb MB · ${(pct * 100).toStringAsFixed(0)}%'
                            : '$mb MB downloaded',
                        'extracting' =>
                          'Unpacking model files ($_extractedFiles of 4)…',
                        _ => 'Connecting…',
                      },
                    ),
                  ),
                  if (_phase != 'extracting') ...[
                    const SizedBox(height: Space.md),
                    TextButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pause download'),
                    ),
                  ],
                ],
                if (_paused && !_started && _error == null) ...[
                  const SizedBox(height: Space.lg),
                  const StatusBanner(
                    tone: StatusTone.info,
                    message:
                        'Download paused. Resume any time — it continues from where it stopped.',
                  ),
                ],
                if (_done) ...[
                  const SizedBox(height: Space.lg),
                  const StatusBanner(
                    tone: StatusTone.success,
                    message: 'Speech model installed. You are ready to dictate.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: Space.lg),
                  StatusBanner(
                    title: 'Download didn’t finish',
                    message: _error!,
                  ),
                ],
                const SizedBox(height: Space.xl),
                if (!_started && !_done)
                  FilledButton.icon(
                    onPressed: _start,
                    icon: Icon(_paused || _error != null
                        ? Icons.refresh_rounded
                        : Icons.download_rounded),
                    label: Text(_paused || _error != null
                        ? 'Resume download'
                        : 'Download model'),
                  ),
                if (!_started && !_done) const SizedBox(height: Space.md),
                if (widget.inOnboarding && _done)
                  FilledButton(
                    onPressed: widget.onNext,
                    child: const Text('Continue'),
                  )
                else if (widget.inOnboarding)
                  OutlinedButton(
                    onPressed: widget.onNext,
                    child: const Text('Skip for now'),
                  )
                else if (_done)
                  FilledButton(
                    onPressed: widget.onNext,
                    child: const Text('Done'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.value, required this.label});

  final double? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: value,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
        ),
        const SizedBox(height: Space.sm),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
