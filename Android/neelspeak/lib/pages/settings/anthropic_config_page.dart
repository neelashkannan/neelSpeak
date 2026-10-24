import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/app_theme.dart';
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
  bool _hasKey = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _model.text = ref.read(settingsProvider).anthropicModel;
    final hasKey = await ref
        .read(settingsChannelProvider)
        .hasSecure(Keys.cloudAnthropicKey);
    if (mounted) {
      setState(() {
        _hasKey = hasKey;
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final model = _model.text.trim();
    await ref
        .read(settingsProvider.notifier)
        .set(Keys.cloudAnthropicModel, model.isEmpty ? null : model);
    final key = _key.text.trim();
    // Blank keeps the saved key.
    if (key.isNotEmpty) {
      await ref.read(settingsChannelProvider).setSecure(Keys.cloudAnthropicKey, key);
    }
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _removeKey() async {
    await ref.read(settingsChannelProvider).clearSecure(Keys.cloudAnthropicKey);
    if (mounted) setState(() => _hasKey = false);
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
            padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxl),
            children: [
              const SectionIntro(
                title: 'Connect Anthropic',
                subtitle:
                    'Clean up dictation with Claude using your own API key from console.anthropic.com. Only the transcribed text is sent.',
              ),
              const SizedBox(height: Space.xl),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _key,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'API key',
                        hintText: _hasKey ? 'Saved — leave blank to keep it' : 'sk-ant-…',
                        helperText: _hasKey ? 'A key is saved on this device.' : null,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _model,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        hintText: defaultAnthropicModel,
                        helperText: 'Leave blank for the default ($defaultAnthropicModel).',
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                    if (_hasKey) ...[
                      const SizedBox(height: Space.sm),
                      TextButton.icon(
                        onPressed: _removeKey,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove saved key'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              const GlassPanel(
                child: DetailRow(
                  label: 'Default model',
                  value:
                      '$defaultAnthropicModel — fast and inexpensive, a good fit for tidying dictation.',
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
