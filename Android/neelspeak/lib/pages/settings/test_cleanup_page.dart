import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _input,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Raw transcript'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _running ? null : _run,
            child: Text(_running ? 'Running…' : 'Run cleanup'),
          ),
          if (_output != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Output (${_latencyMs ?? 0} ms)',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    SelectableText(_output!),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
