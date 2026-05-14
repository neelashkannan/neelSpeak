import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
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
  bool _warming = false;
  String? _transcript;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final installed =
        await ref.read(modelChannelProvider).isParakeetInstalled();
    if (!mounted) return;
    setState(() => _modelInstalled = installed);
    if (installed) {
      await _warm();
    }
  }

  Future<void> _warm() async {
    setState(() {
      _warming = true;
      _error = null;
    });
    try {
      final ok = await ref.read(dictationChannelProvider).warm();
      if (!mounted) return;
      setState(() {
        _warming = false;
        if (!ok) {
          _error = 'Parakeet runtime is not installed in this app build.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _warming = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _start() async {
    setState(() {
      _recording = true;
      _transcribing = false;
      _transcript = null;
      _error = null;
    });
    try {
      final state = await ref.read(dictationChannelProvider).start();
      if (state == 'setupRequired') {
        setState(() {
          _recording = false;
          _modelInstalled = false;
          _error =
              'Parakeet is not installed yet. Go back and download the speech model.';
        });
      } else if (state == 'error') {
        setState(() {
          _recording = false;
          _error = 'Could not start recording. Check microphone permission.';
        });
      }
    } catch (e) {
      setState(() {
        _recording = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _stop() async {
    setState(() {
      _recording = false;
      _transcribing = true;
      _error = null;
    });
    try {
      final transcript =
          await ref.read(dictationChannelProvider).stopAndAwait();
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _transcript = transcript.trim().isEmpty
            ? 'No words detected. Try again and speak for a little longer.'
            : transcript.trim();
      });
    } catch (e) {
      setState(() {
        _transcribing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = _modelInstalled && !_transcribing && !_warming;

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
                    Icons.record_voice_over_rounded,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Test Parakeet STT',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Record a short phrase to confirm the local Parakeet speech model works before you finish onboarding.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 24),
                if (!_modelInstalled)
                  const GlassPanel(
                    padding: EdgeInsets.all(18),
                    child: DetailRow(
                      label: 'Speech model required',
                      value: 'Go back and download Parakeet before testing STT.',
                      icon: Icons.download_rounded,
                    ),
                  ),
                if (_warming || _transcribing) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 10),
                  Text(_warming
                      ? 'Warming Parakeet...'
                      : 'Transcribing with Parakeet...'),
                ],
                if (_transcript != null) ...[
                  const SizedBox(height: 20),
                  GlassPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transcript',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        SelectableText(_transcript!),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final recordButton = FilledButton.icon(
                      onPressed: !canRecord
                          ? null
                          : _recording
                              ? _stop
                              : _start,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(_recording ? 'Stop' : 'Record'),
                    );

                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton(
                            onPressed: widget.onNext,
                            child: const Text('Skip test'),
                          ),
                          const SizedBox(height: 12),
                          recordButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onNext,
                            child: const Text('Skip test'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: recordButton),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _transcript == null ? null : widget.onNext,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
