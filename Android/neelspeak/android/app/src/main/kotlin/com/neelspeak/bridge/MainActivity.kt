package com.neelspeak.bridge

import com.neelspeak.app.NeelSpeakApplication
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Flutter host. Registers every platform-channel handler the Dart side uses
 * to read/write settings, drive the model download, run Copilot OAuth, and
 * mirror IME state. Native settings live in SharedPreferences in this same
 * package — the IME service writes the same files.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        SettingsChannel(this).register(messenger)
        ModelChannel(this).register(messenger)
        CopilotAuthChannel(this).register(messenger)
        ImeStatusChannel(this).register(messenger)
        SystemChannel(this).register(messenger)
        CleanupChannel(this).register(messenger)
        DictationChannel(application as NeelSpeakApplication).register(messenger)
    }
}
