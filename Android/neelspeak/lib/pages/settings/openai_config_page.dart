import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';

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
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('OpenAI-compatible')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SectionIntro(
                eyebrow: 'Provider configuration',
                title: 'Connect any OpenAI-compatible endpoint.',
                subtitle:
                    'Point NeelSpeak at OpenAI, Groq, OpenRouter, GitHub Models, Ollama, or your own compatible server.',
              ),
              const SizedBox(height: 20),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _baseUrl,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _model,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _key,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'API key'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final n = ref.read(settingsProvider.notifier);
                        await n.set(Keys.cloudOpenAiBaseUrl, _baseUrl.text.trim());
                        await n.set(Keys.cloudOpenAiModel, _model.text.trim());
                        await ref
                            .read(settingsChannelProvider)
                            .setSecure(Keys.cloudOpenAiKey, _key.text);
                        if (!mounted) return;
                        navigator.pop();
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save configuration'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(
                      label: 'Recommended presets',
                      value:
                          'OpenAI: api.openai.com/v1 · Groq: api.groq.com/openai/v1',
                      icon: Icons.bolt_rounded,
                    ),
                    SizedBox(height: 16),
                    DetailRow(
                      label: 'Self-hosted options',
                      value:
                          'OpenRouter: openrouter.ai/api/v1 · Ollama on emulator host: 10.0.2.2:11434/v1',
                      icon: Icons.hub_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
