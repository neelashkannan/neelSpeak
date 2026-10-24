import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static const cleanupLastError = 'cleanup.lastError';
  static const cleanupLastErrorAt = 'cleanup.lastErrorAt';
}

/// Default Anthropic model. Keep in sync with
/// LlmTranscriptCleaner.DEFAULT_ANTHROPIC_MODEL on the Kotlin side.
const defaultAnthropicModel = 'claude-haiku-5-5';

class Settings {
  Settings({
    this.setupComplete = false,
    this.cleanupMode = 'off',
    this.cleanupEngine = 'openAICompatible',
    this.openAiBaseUrl = 'https://api.openai.com/v1',
    this.openAiModel = 'gpt-4o-mini',
    this.anthropicModel = defaultAnthropicModel,
    this.copilotModel = 'gpt-4o-mini',
    this.lastCleanupError,
    this.lastCleanupErrorAt,
  });

  final bool setupComplete;
  final String cleanupMode;
  final String cleanupEngine;
  final String openAiBaseUrl;
  final String openAiModel;
  final String anthropicModel;
  final String copilotModel;

  /// Why the most recent cleanup fell back to the raw transcript, if it did.
  final String? lastCleanupError;
  final DateTime? lastCleanupErrorAt;

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
        lastCleanupError: lastCleanupError,
        lastCleanupErrorAt: lastCleanupErrorAt,
      );

  static Settings fromMap(Map<String, Object?> map) => Settings(
        setupComplete: map[Keys.setupComplete] as bool? ?? false,
        cleanupMode: map[Keys.cleanupMode] as String? ?? 'off',
        cleanupEngine: map[Keys.cleanupEngine] as String? ?? 'openAICompatible',
        openAiBaseUrl: map[Keys.cloudOpenAiBaseUrl] as String? ?? 'https://api.openai.com/v1',
        openAiModel: map[Keys.cloudOpenAiModel] as String? ?? 'gpt-4o-mini',
        anthropicModel: _nonEmpty(map[Keys.cloudAnthropicModel]) ?? defaultAnthropicModel,
        copilotModel: map[Keys.cloudCopilotModel] as String? ?? 'gpt-4o-mini',
        lastCleanupError: _nonEmpty(map[Keys.cleanupLastError]),
        lastCleanupErrorAt: switch (map[Keys.cleanupLastErrorAt]) {
          final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
          _ => null,
        },
      );

  static String? _nonEmpty(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;
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

  Future<void> clearCleanupError() async {
    await _ch.set(Keys.cleanupLastError, null);
    await _ch.set(Keys.cleanupLastErrorAt, null);
    await refresh();
  }
}

final settingsChannelProvider = Provider<SettingsChannel>((_) => SettingsChannel());
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) => SettingsNotifier(ref.watch(settingsChannelProvider)));

final systemChannelProvider = Provider<SystemChannel>((_) => SystemChannel());
final modelChannelProvider = Provider<ModelChannel>((_) => ModelChannel());
final copilotChannelProvider = Provider<CopilotChannel>((_) => CopilotChannel());
final cleanupChannelProvider = Provider<CleanupChannel>((_) => CleanupChannel());
final dictationChannelProvider = Provider<DictationChannel>((_) => DictationChannel());

final imeStatusProvider = StreamProvider<Map<Object?, Object?>>((_) => ImeStatusChannel().stream());
final modelDownloadProvider =
    StreamProvider<Map<Object?, Object?>>((ref) => ref.watch(modelChannelProvider).progress());

/// Everything the keyboard needs before it can type. Re-read whenever the
/// app comes back to the foreground (the user may have just changed a system
/// setting), so call `ref.invalidate(setupStatusProvider)` on resume.
class SetupStatus {
  const SetupStatus({
    required this.micGranted,
    required this.micPermanentlyDenied,
    required this.modelInstalled,
    required this.imeEnabled,
    required this.imeSelected,
  });

  final bool micGranted;
  final bool micPermanentlyDenied;
  final bool modelInstalled;
  final bool imeEnabled;
  final bool imeSelected;

  bool get complete => micGranted && modelInstalled && imeEnabled && imeSelected;
}

final setupStatusProvider = FutureProvider.autoDispose<SetupStatus>((ref) async {
  final system = ref.watch(systemChannelProvider);
  final model = ref.watch(modelChannelProvider);
  final mic = await Permission.microphone.status;
  final results = await Future.wait([
    model.isParakeetInstalled(),
    system.isEnabledIme(),
    system.isDefaultIme(),
  ]);
  return SetupStatus(
    micGranted: mic.isGranted,
    micPermanentlyDenied: mic.isPermanentlyDenied,
    modelInstalled: results[0],
    imeEnabled: results[1],
    imeSelected: results[2],
  );
});

final appVersionProvider = FutureProvider<String>(
    (ref) => ref.watch(systemChannelProvider).appVersion());
