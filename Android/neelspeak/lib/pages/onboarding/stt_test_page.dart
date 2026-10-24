import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/app_theme.dart';
import '../../ui/premium_widgets.dart';

class SttTestPage extends ConsumerStatefulWidget {
  const SttTestPage({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<SttTestPage> createState() => _SttTestPageState();
}

class _SttTestPageState extends ConsumerState<SttTestPage> {
  bool _recording = false;
  bool _transcribing = false;
  bool _modelInstalled = false;
  bool _engineReady = false;
  bool _warming = false;
  String? _transcript;
  bool _heardNothing = false;
  String? _error;
  late final _dictation = ref.read(dictationChannelProvider);

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  @override
  void dispose() {
    // Leaving mid-test must not keep the microphone open.
    if (_recording || _transcribing) {
      _dictation.cancel();
    }
    super.dispose();
  }

  Future<void> _checkModel() async {
    final installed =
        await ref.read(modelChannelProvider).isParakeetInstalled();
    if (!mounted) return;
    setState(() => _modelInstalled = installed);
  }

  Future<bool> _warm() async {
    setState(() {
      _warming = true;
      _error = null;
    });
    try {
      final ok = await _dictation.warm();
      if (!mounted) return false;
      setState(() {
        _warming = false;
        _engineReady = ok;
        if (!ok) {
          _error =
              'The speech model couldn’t be loaded. Go back one step and download it again.';
        }
      });
      return ok;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _warming = false;
        _engineReady = false;
        _error = 'The speech model couldn’t be loaded.';
      });
      return false;
    }
  }

  Future<void> _start() async {
    if (!_engineReady) {
      final warmed = await _warm();
      if (!warmed || !mounted) return;
    }
    setState(() {
      _recording = true;
      _transcribing = false;
      _transcript = null;
      _heardNothing = false;
      _error = null;
    });
    final dictation = _dictation;
    try {
      final state = await dictation.start();
      if (!mounted) return;
      if (state == 'busy') {
        setState(() {
          _recording = false;
          _error = 'The keyboard is dictating right now. Try again in a moment.';
        });
      } else if (state == 'setupRequired') {
        setState(() {
          _recording = false;
          _modelInstalled = false;
          _error =
              'The speech model isn’t installed yet. Go back one step and download it.';
        });
      } else if (state == 'error') {
        final message = await dictation.errorMessage();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _error = message ?? 'Couldn’t start recording. Check microphone access.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _error = 'Couldn’t start recording. Check microphone access.';
      });
    }
  }

  Future<void> _stop() async {
    setState(() {
      _recording = false;
      _transcribing = true;
      _error = null;
    });
    final dictation = _dictation;
    try {
      final transcript = await dictation.stopAndAwait();
      final message = await dictation.errorMessage();
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        if (transcript.trim().isNotEmpty) {
          _transcript = transcript.trim();
        } else if (message != null) {
          _error = message;
        } else {
          _heardNothing = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _error = 'Transcription failed. Try again.';
      });
    }
  }

  Future<void> _cancel() async {
    await _dictation.cancel();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canRecord = _modelInstalled && !_transcribing && !_warming;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StepIcon(icon: Icons.record_voice_over_rounded),
                const SizedBox(height: Space.xxl),
                Semantics(
                  header: true,
                  child: Text(
                    'Try it out',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Tap Record, say a sentence, then tap Stop. This checks that speech recognition works on your phone before you use the keyboard.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: Space.lg),
                if (_modelInstalled && !_recording && !_transcribing && !_warming)
                  InfoPill(
                    label: _engineReady
                        ? 'Speech engine ready'
                        : 'First recording takes a few seconds to load',
                    icon: _engineReady ? Icons.check_circle : Icons.hourglass_top_rounded,
                    tint: _engineReady ? theme.colorScheme.success : null,
                  ),
                if (!_modelInstalled)
                  const StatusBanner(
                    tone: StatusTone.warning,
                    title: 'Speech model needed',
                    message: 'Go back one step and download the model first.',
                  ),
                if (_recording) ...[
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Icon(Icons.fiber_manual_record_rounded,
                            color: theme.colorScheme.error, size: 18),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text('Listening… tap Stop when you’re done.',
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_warming || _transcribing) ...[
                  const SizedBox(height: Space.lg),
                  LinearProgressIndicator(
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(_warming
                      ? 'Loading the speech model…'
                      : 'Turning your speech into text…'),
                ],
                if (_transcript != null) ...[
                  const SizedBox(height: Space.xl),
                  GlassPanel(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You said',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: Space.sm),
                        SelectableText(_transcript!),
                      ],
                    ),
                  ),
                ],
                if (_heardNothing) ...[
                  const SizedBox(height: Space.xl),
                  const StatusBanner(
                    tone: StatusTone.info,
                    message:
                        'No words were picked up. Hold the phone a little closer and speak for at least a second.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: Space.xl),
                  StatusBanner(message: _error!),
                ],
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: !canRecord
                      ? null
                      : _recording
                          ? _stop
                          : _start,
                  icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                  label: Text(_recording
                      ? 'Stop'
                      : _transcript != null || _heardNothing
                          ? 'Record again'
                          : 'Record'),
                ),
                if (_recording || _transcribing) ...[
                  const SizedBox(height: Space.md),
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancel'),
                  ),
                ],
                const SizedBox(height: Space.md),
                if (_transcript != null)
                  FilledButton.tonal(
                    onPressed: widget.onNext,
                    child: const Text('Continue'),
                  )
                else
                  OutlinedButton(
                    onPressed: widget.onNext,
                    child: const Text('Skip test'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
