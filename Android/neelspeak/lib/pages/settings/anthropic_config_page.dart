import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';

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
    _key.text = (await ref
            .read(settingsChannelProvider)
            .getSecure(Keys.cloudAnthropicKey)) ??
        '';
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Anthropic Claude')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SectionIntro(
                eyebrow: 'Provider configuration',
                title: 'Set up Anthropic Claude.',
                subtitle:
                    'Use a direct Anthropic API key when you want a dedicated Claude cleanup path instead of a generic OpenAI-compatible endpoint.',
              ),
              const SizedBox(height: 20),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credentials',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _model,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _key,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API key (x-api-key)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await ref
                            .read(settingsProvider.notifier)
                            .set(Keys.cloudAnthropicModel, _model.text.trim());
                        await ref
                            .read(settingsChannelProvider)
                            .setSecure(Keys.cloudAnthropicKey, _key.text);
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
                child: DetailRow(
                  label: 'Default model',
                  value:
                      'claude-haiku-4-5. You can create keys in the Anthropic Console.',
                  icon: Icons.tips_and_updates_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
