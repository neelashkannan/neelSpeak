import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/channels.dart';

/// Native SharedPreferences keys. Must match
/// android/.../com/neelspeak/prefs/SettingsKeys.kt verbatim.
class Keys {
  static const setupComplete = 'setupComplete';
  static const cleanupMode = 'cleanupMode';
  static const cleanupEngine = 'cleanupEngine';
  static const cloudOpenAiBaseUrl = 'cloud.openai.baseURL';
  static const cloudOpenAiModel = 'cloud.openai.model';
  static const cloudAnthropicModel = 'cloud.anthropic.model';
  static const cloudCopilotModel = 'cloud.copilot.model';
  static const cloudOpenAiKey = 'cloud.openai.apiKey';
  static const cloudAnthropicKey = 'cloud.anthropic.apiKey';
  static const cloudCopilotOAuth = 'cloud.copilot.oauthToken';
  static const cloudHfToken = 'cloud.huggingface.token';
  static const onDeviceLlmId = 'onDevice.llm.id';
}

class Settings {
  Settings({
    this.setupComplete = false,
    this.cleanupMode = 'off',
    this.cleanupEngine = 'openAICompatible',
    this.openAiBaseUrl = 'https://api.openai.com/v1',
    this.openAiModel = 'gpt-4o-mini',
    this.anthropicModel = 'claude-haiku-4-5',
    this.copilotModel = 'gpt-4o-mini',
  });

  final bool setupComplete;
  final String cleanupMode;
  final String cleanupEngine;
  final String openAiBaseUrl;
  final String openAiModel;
  final String anthropicModel;
  final String copilotModel;

  Settings copyWith({
    bool? setupComplete,
    String? cleanupMode,
    String? cleanupEngine,
    String? openAiBaseUrl,
    String? openAiModel,
    String? anthropicModel,
    String? copilotModel,
  }) =>
      Settings(
        setupComplete: setupComplete ?? this.setupComplete,
        cleanupMode: cleanupMode ?? this.cleanupMode,
        cleanupEngine: cleanupEngine ?? this.cleanupEngine,
        openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
        openAiModel: openAiModel ?? this.openAiModel,
        anthropicModel: anthropicModel ?? this.anthropicModel,
        copilotModel: copilotModel ?? this.copilotModel,
      );

  static Settings fromMap(Map<String, Object?> map) => Settings(
        setupComplete: map[Keys.setupComplete] as bool? ?? false,
        cleanupMode: map[Keys.cleanupMode] as String? ?? 'off',
        cleanupEngine: map[Keys.cleanupEngine] as String? ?? 'openAICompatible',
        openAiBaseUrl: map[Keys.cloudOpenAiBaseUrl] as String? ?? 'https://api.openai.com/v1',
        openAiModel: map[Keys.cloudOpenAiModel] as String? ?? 'gpt-4o-mini',
        anthropicModel: map[Keys.cloudAnthropicModel] as String? ?? 'claude-haiku-4-5',
        copilotModel: map[Keys.cloudCopilotModel] as String? ?? 'gpt-4o-mini',
      );
}

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier(this._ch) : super(Settings()) {
    refresh();
  }
  final SettingsChannel _ch;

  Future<void> refresh() async {
    final map = await _ch.getAll();
    state = Settings.fromMap(map);
  }

  Future<void> set(String key, Object? value) async {
    await _ch.set(key, value);
    await refresh();
  }

  Future<void> setCleanupMode(String mode) => set(Keys.cleanupMode, mode);
  Future<void> setCleanupEngine(String engine) => set(Keys.cleanupEngine, engine);
  Future<void> markSetupComplete() => set(Keys.setupComplete, true);
}

final settingsChannelProvider = Provider<SettingsChannel>((_) => SettingsChannel());
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) => SettingsNotifier(ref.watch(settingsChannelProvider)));

final systemChannelProvider = Provider<SystemChannel>((_) => SystemChannel());
final modelChannelProvider = Provider<ModelChannel>((_) => ModelChannel());
final copilotChannelProvider = Provider<CopilotChannel>((_) => CopilotChannel());
final cleanupChannelProvider = Provider<CleanupChannel>((_) => CleanupChannel());

final imeStatusProvider = StreamProvider<Map<Object?, Object?>>((_) => ImeStatusChannel().stream());
final modelDownloadProvider =
    StreamProvider<Map<Object?, Object?>>((ref) => ref.watch(modelChannelProvider).progress());
