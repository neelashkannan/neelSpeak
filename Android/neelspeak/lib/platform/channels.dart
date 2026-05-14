import 'package:flutter/services.dart';

/// Thin Dart facades for the platform channels exposed by the native Kotlin
/// MainActivity. Keep these in sync with the channel names in
/// android/app/src/main/kotlin/com/neelspeak/bridge/*.
class SettingsChannel {
  static const _channel = MethodChannel('neelspeak/settings');

  Future<Map<String, Object?>> getAll() async {
    final result = await _channel.invokeMapMethod<String, Object?>('getAll');
    return result ?? <String, Object?>{};
  }

  Future<void> set(String key, Object? value) =>
      _channel.invokeMethod<void>('set', {'key': key, 'value': value});

  Future<String?> getSecure(String key) =>
      _channel.invokeMethod<String>('getSecure', {'key': key});

  Future<void> setSecure(String key, String value) =>
      _channel.invokeMethod<void>('setSecure', {'key': key, 'value': value});

  Future<void> clearSecure(String key) =>
      _channel.invokeMethod<void>('clearSecure', {'key': key});
}

class SystemChannel {
  static const _channel = MethodChannel('neelspeak/system');

  Future<void> openImeSettings() =>
      _channel.invokeMethod<void>('openImeSettings');
  Future<void> showImePicker() => _channel.invokeMethod<void>('showImePicker');
  Future<bool> isEnabledIme() async =>
      await _channel.invokeMethod<bool>('isEnabledIme') ?? false;
  Future<bool> isDefaultIme() async =>
      await _channel.invokeMethod<bool>('isDefaultIme') ?? false;

  /// Tries to open [url] in [preferredPackage] (e.g. "com.github.android"); if
  /// the app isn't installed, falls back to the default browser. Returns one
  /// of "app", "browser", or "none".
  Future<String> openUrlPreferringApp(String url,
      {String? preferredPackage}) async {
    final result = await _channel.invokeMethod<String>(
      'openUrlPreferringApp',
      {'url': url, 'package': preferredPackage},
    );
    return result ?? 'none';
  }
}

class ModelChannel {
  static const _channel = MethodChannel('neelspeak/model');
  static const _progress = EventChannel('neelspeak/model/progress');

  Future<bool> isParakeetInstalled() async =>
      await _channel.invokeMethod<bool>('isParakeetInstalled') ?? false;
  Future<bool> isLlmInstalled() async =>
      await _channel.invokeMethod<bool>('isLlmInstalled') ?? false;

  Future<void> downloadParakeet() =>
      _channel.invokeMethod<void>('downloadParakeet');
  Future<void> downloadLlm(String url) =>
      _channel.invokeMethod<void>('downloadLlm', {'url': url});

  Future<void> cancelDownload() =>
      _channel.invokeMethod<void>('cancelDownload');
  Future<void> deleteParakeet() =>
      _channel.invokeMethod<void>('deleteParakeet');
  Future<void> deleteLlm() => _channel.invokeMethod<void>('deleteLlm');

  Stream<Map<Object?, Object?>> progress() =>
      _progress.receiveBroadcastStream().cast<Map<Object?, Object?>>();
}

class CopilotChannel {
  static const _channel = MethodChannel('neelspeak/copilot');

  Future<Map<String, Object?>> requestDeviceCode() async {
    final r =
        await _channel.invokeMapMethod<String, Object?>('requestDeviceCode');
    return r ?? <String, Object?>{};
  }

  Future<void> pollForOAuthToken({
    required String deviceCode,
    required int intervalSeconds,
    required int expiresAtMillis,
  }) =>
      _channel.invokeMethod<void>('pollForOAuthToken', {
        'deviceCode': deviceCode,
        'intervalSeconds': intervalSeconds,
        'expiresAtMillis': expiresAtMillis,
      });

  Future<void> signOut() => _channel.invokeMethod<void>('signOut');
}

class CleanupChannel {
  static const _channel = MethodChannel('neelspeak/cleanup');

  Future<Map<String, Object?>> test(
      {required String text, required String mode}) async {
    final r = await _channel.invokeMapMethod<String, Object?>(
      'test',
      {'text': text, 'mode': mode},
    );
    return r ?? <String, Object?>{};
  }

  Future<List<String>> fetchCopilotModels() async {
    final r = await _channel.invokeListMethod<String>('fetchCopilotModels');
    return r ?? const <String>[];
  }
}

class ImeStatusChannel {
  static const _channel = EventChannel('neelspeak/ime/status');
  Stream<Map<Object?, Object?>> stream() =>
      _channel.receiveBroadcastStream().cast<Map<Object?, Object?>>();
}

/// Lets the onboarding "Test STT" page drive the shared coordinator without
/// going through the keyboard.
class DictationChannel {
  static const _channel = MethodChannel('neelspeak/dictation');

  Future<bool> warm() async =>
      await _channel.invokeMethod<bool>('warm') ?? false;
  Future<String> start() async =>
      await _channel.invokeMethod<String>('start') ?? '';
  Future<String> stopAndAwait() async =>
      await _channel.invokeMethod<String>('stopAndAwait') ?? '';
  Future<String> state() async =>
      await _channel.invokeMethod<String>('state') ?? '';
}
