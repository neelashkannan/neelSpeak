import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';

class TestCleanupPage extends ConsumerStatefulWidget {
  const TestCleanupPage({super.key});
  @override
  ConsumerState<TestCleanupPage> createState() => _TestCleanupPageState();
}

class _TestCleanupPageState extends ConsumerState<TestCleanupPage> {
  final _input = TextEditingController(text: 'um so like the the meeting is at three you know');
  String? _output;
  int? _latencyMs;
  String? _error;
  bool _running = false;

  Future<void> _run() async {
    setState(() { _running = true; _error = null; _output = null; _latencyMs = null; });
    try {
      final mode = ref.read(settingsProvider).cleanupMode;
      final r = await ref.read(cleanupChannelProvider).test(
        text: _input.text,
        mode: mode == 'off' ? 'conservative' : mode,
      );
      setState(() {
        _output = r['result'] as String?;
        _latencyMs = r['latencyMs'] as int?;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test cleanup')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SectionIntro(
                eyebrow: 'Verification',
                title: 'Dry-run the current cleanup stack.',
                subtitle:
                    'Send a sample transcript through the configured cleanup engine and check the final output before you start dictating.',
              ),
              const SizedBox(height: 20),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _input,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Raw transcript',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _running ? null : _run,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(_running ? 'Running…' : 'Run cleanup'),
                    ),
                  ],
                ),
              ),
              if (_output != null) ...[
                const SizedBox(height: 16),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoPill(
                        label: 'Output (${_latencyMs ?? 0} ms)',
                        icon: Icons.timer_outlined,
                      ),
                      const SizedBox(height: 16),
                      SelectableText(_output!),
                    ],
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
