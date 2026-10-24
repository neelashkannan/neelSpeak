import AppKit

// `NeelSpeak --transcribe <audio-file> [--cleanup conservative|aggressive]`
// runs the dictation pipeline on a file and prints the result. Useful for
// diagnosing transcription without the hotkey or permissions.
if let index = CommandLine.arguments.firstIndex(of: "--transcribe") {
    exit(CommandLineTranscriber.run(arguments: Array(CommandLine.arguments[(index + 1)...])))
}

#if DEBUG
// `NeelSpeak --render-ui <dir>` writes PNGs of every window pane (debug builds only).
if let index = CommandLine.arguments.firstIndex(of: "--render-ui"), CommandLine.arguments.indices.contains(index + 1) {
    MainActor.assumeIsolated {
        UISnapshotRenderer.run(outputDirectory: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
    }
    exit(0)
}
#endif

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
