import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';

class ModelDownloadPage extends ConsumerStatefulWidget {
  const ModelDownloadPage({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends ConsumerState<ModelDownloadPage> {
  bool _started = false;
  bool _done = false;
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
    final installed =
        await ref.read(modelChannelProvider).isParakeetInstalled();
    if (installed && mounted) {
      setState(() {
        _done = true;
        _phase = 'done';
      });
    }
  }

  Future<void> _start() async {
    await _sub?.cancel();
    setState(() {
      _started = true;
      _phase = 'starting';
      _bytes = 0;
      _total = 0;
      _extractedFiles = 0;
      _error = null;
    });
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
        } else if (_phase == 'failed') {
          _error = event['message'] as String?;
          _sub?.cancel();
        }
      });
    });
    try {
      await ref.read(modelChannelProvider).downloadParakeet();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _started = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = _total > 0 ? _bytes / _total : null;
    final mb = (_bytes / 1024 / 1024).toStringAsFixed(1);
    final totalMb =
        _total > 0 ? (_total / 1024 / 1024).toStringAsFixed(0) : '~190';

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
                    Icons.download_for_offline_rounded,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Download speech model',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'NeelSpeak transcribes on-device using NVIDIA Parakeet TDT. Download size is about 190 MB, so Wi-Fi is recommended.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 24),
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DetailRow(
                        label: 'Runtime',
                        value: 'NVIDIA Parakeet TDT running locally on-device',
                        icon: Icons.memory_rounded,
                      ),
                      const SizedBox(height: 16),
                      const DetailRow(
                        label: 'Download size',
                        value: 'Approximately 190 MB',
                        icon: Icons.storage_rounded,
                      ),
                      if (_started && !_done && _error == null) ...[
                        const SizedBox(height: 20),
                        if (_phase == 'downloading') ...[
                          LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            pct != null
                                ? '$mb / $totalMb MB (${(pct * 100).toStringAsFixed(1)}%)'
                                : '$mb MB downloaded',
                          ),
                        ] else if (_phase == 'extracting') ...[
                          const LinearProgressIndicator(minHeight: 8),
                          const SizedBox(height: 10),
                          Text('Extracting model files: $_extractedFiles'),
                        ] else ...[
                          const LinearProgressIndicator(minHeight: 8),
                          const SizedBox(height: 10),
                          Text('Phase: $_phase'),
                        ],
                      ],
                      if (_done) ...[
                        const SizedBox(height: 20),
                        const InfoPill(
                          label: 'Model installed',
                          icon: Icons.check_circle,
                          tint: Colors.green,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _start,
                          child: const Text('Retry download'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (!_started && !_done)
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Start download'),
                  ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton(
                            onPressed: widget.onNext,
                            child: const Text('Skip for now'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _done ? widget.onNext : null,
                            child: const Text('Continue'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onNext,
                            child: const Text('Skip for now'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _done ? widget.onNext : null,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
