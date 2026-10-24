import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_provider.dart';
import '../../ui/app_theme.dart';
import '../../ui/premium_widgets.dart';

/// Provider presets. Mirrors OpenAiCompatPreset.all in
/// android/.../cleanup/CleanupMode.kt.
class _Preset {
  const _Preset(this.id, this.name, this.baseUrl, this.model, this.keyHint);
  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final String keyHint;
}

const _presets = <_Preset>[
  _Preset('github-models', 'GitHub Models (free)', 'https://models.github.ai/inference',
      'openai/gpt-4o-mini', 'GitHub token from github.com/settings/tokens (no scopes needed)'),
  _Preset('openai', 'OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini',
      'sk-… from platform.openai.com'),
  _Preset('openrouter', 'OpenRouter', 'https://openrouter.ai/api/v1', 'openai/gpt-4o-mini',
      'sk-or-… from openrouter.ai/keys'),
  _Preset('groq', 'Groq (fast)', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile',
      'gsk_… from console.groq.com'),
  _Preset('ollama', 'Ollama (local)', 'http://10.0.2.2:11434/v1', 'llama3.2:3b',
      'Any value — Ollama ignores it. 10.0.2.2 reaches your computer from the emulator.'),
  _Preset('opencode', 'OpenCode (local server)', 'http://localhost:4096/v1',
      'anthropic/claude-haiku-5-5',
      'Any value — run “opencode serve”; it uses the providers in your opencode config.'),
];

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
  bool _hasKey = false;
  bool _saving = false;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = ref.read(settingsProvider);
    _baseUrl.text = s.openAiBaseUrl;
    _model.text = s.openAiModel;
    final hasKey =
        await ref.read(settingsChannelProvider).hasSecure(Keys.cloudOpenAiKey);
    if (mounted) {
      setState(() {
        _hasKey = hasKey;
        _loaded = true;
      });
    }
  }

  _Preset? get _matchingPreset {
    final url = _baseUrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    for (final p in _presets) {
      if (p.baseUrl == url) return p;
    }
    return null;
  }

  void _apply(_Preset p) {
    setState(() {
      _baseUrl.text = p.baseUrl;
      _model.text = p.model;
      _urlError = null;
    });
  }

  String? _validateUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a full URL, e.g. https://api.openai.com/v1';
    }
    const local = {'localhost', '127.0.0.1', '10.0.2.2'};
    if (uri.scheme == 'http' && !local.contains(uri.host)) {
      return 'Use https:// — plain http only works for localhost and 10.0.2.2.';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'The URL must start with https://';
    }
    return null;
  }

  Future<void> _save() async {
    final urlError = _validateUrl(_baseUrl.text);
    if (urlError != null) {
      setState(() => _urlError = urlError);
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final n = ref.read(settingsProvider.notifier);
    await n.set(Keys.cloudOpenAiBaseUrl, _baseUrl.text.trim());
    await n.set(Keys.cloudOpenAiModel, _model.text.trim());
    final key = _key.text.trim();
    if (key.isNotEmpty) {
      await ref.read(settingsChannelProvider).setSecure(Keys.cloudOpenAiKey, key);
    }
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _removeKey() async {
    await ref.read(settingsChannelProvider).clearSecure(Keys.cloudOpenAiKey);
    if (mounted) setState(() => _hasKey = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final preset = _matchingPreset;
    return Scaffold(
      appBar: AppBar(title: const Text('OpenAI-compatible')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.sm, Space.page, Space.xxl),
            children: [
              const SectionIntro(
                title: 'Connect a provider',
                subtitle:
                    'Pick a provider to fill in the address and model, then paste your API key. Only the transcribed text is sent.',
              ),
              const SizedBox(height: Space.xl),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Provider', style: theme.textTheme.titleMedium),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final p in _presets)
                          ChoiceChip(
                            label: Text(p.name),
                            selected: preset?.id == p.id,
                            onSelected: (_) => _apply(p),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    TextField(
                      controller: _key,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'API key',
                        hintText: _hasKey ? 'Saved — leave blank to keep it' : null,
                        helperText: preset?.keyHint ??
                            (_hasKey ? 'A key is saved on this device.' : null),
                        helperMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _baseUrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onChanged: (_) => setState(() => _urlError = null),
                      decoration: InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                        errorText: _urlError,
                        errorMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _model,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Model'),
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
                  label: 'Local servers',
                  value:
                      'Ollama and OpenCode can run on this phone (e.g. in Termux) at localhost, or on your computer at 10.0.2.2 from the emulator. Everything else must use https.',
                  icon: Icons.hub_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
