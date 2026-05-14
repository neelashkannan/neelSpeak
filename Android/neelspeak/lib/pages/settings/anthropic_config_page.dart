import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';

class AnthropicConfigPage extends ConsumerStatefulWidget {
  const AnthropicConfigPage({super.key});
  @override
  ConsumerState<AnthropicConfigPage> createState() => _State();
}

class _State extends ConsumerState<AnthropicConfigPage> {
  final _model = TextEditingController();
  final _key = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _model.text = ref.read(settingsProvider).anthropicModel;
    _key.text = (await ref.read(settingsChannelProvider).getSecure(Keys.cloudAnthropicKey)) ?? '';
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Anthropic Claude')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _model, decoration: const InputDecoration(labelText: 'Model')),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API key (x-api-key)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await ref.read(settingsProvider.notifier).set(Keys.cloudAnthropicModel, _model.text.trim());
              await ref.read(settingsChannelProvider).setSecure(Keys.cloudAnthropicKey, _key.text);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get a key at console.anthropic.com. Default model: claude-haiku-4-5.',
          ),
        ],
      ),
    );
  }
}
