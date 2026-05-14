import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';

class OpenAiConfigPage extends ConsumerStatefulWidget {
  const OpenAiConfigPage({super.key});
  @override
  ConsumerState<OpenAiConfigPage> createState() => _OpenAiConfigPageState();
}

class _OpenAiConfigPageState extends ConsumerState<OpenAiConfigPage> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = ref.read(settingsProvider);
    _baseUrl.text = s.openAiBaseUrl;
    _model.text = s.openAiModel;
    final ch = ref.read(settingsChannelProvider);
    _key.text = (await ch.getSecure(Keys.cloudOpenAiKey)) ?? '';
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('OpenAI-compatible')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://api.openai.com/v1'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _model, decoration: const InputDecoration(labelText: 'Model')),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API key'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final n = ref.read(settingsProvider.notifier);
              await n.set(Keys.cloudOpenAiBaseUrl, _baseUrl.text.trim());
              await n.set(Keys.cloudOpenAiModel, _model.text.trim());
              await ref.read(settingsChannelProvider).setSecure(Keys.cloudOpenAiKey, _key.text);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Presets: api.openai.com/v1 (gpt-4o-mini), api.groq.com/openai/v1 (llama-3.3-70b-versatile), '
            'openrouter.ai/api/v1, 10.0.2.2:11434/v1 (Ollama on host loopback from emulator).',
          ),
        ],
      ),
    );
  }
}
