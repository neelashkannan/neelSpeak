import AppKit
import Foundation

/// What one completed dictation produced.
struct DictationResult {
    let text: String
    /// Parakeet's transcript before cleanup, when cleanup changed it.
    let rawText: String?
    /// Why cleanup was skipped, when it was requested but couldn't run.
    let cleanupIssue: String?
    let audioDuration: TimeInterval
}

@MainActor
final class DictationCoordinator {
    enum State {
        case setupRequired
        case downloadingModel(Double)
        case warming
        case idle
        case recording
        case transcribing
        case cleaning
        case error(String)
    }

    /// Short-lived messages shown in the overlay pill.
    enum Notice: Equatable {
        case noSpeech
        case notReady(String)
        case microphoneUnavailable
        case cleanupSkipped
    }

    /// Holds shorter than this are treated as an accidental tap of the key.
    private static let minimumHold: TimeInterval = 0.25
    /// Less audio than this (0.3 s at 16 kHz) can't contain a word.
    private static let minimumSamples = 4_800

    var onStateChange: ((State) -> Void)?
    var onResult: ((DictationResult) -> Void)?
    var onNotice: ((Notice) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onCleanupState: ((LLMTranscriptCleaner.LoadState) -> Void)?

    private let audio = AudioEngine()
    private let hotkey = HotkeyManager()
    private let whisper = WhisperService()
    private let cleaner = LLMTranscriptCleaner()
    private var hotkeyStarted = false
    private var recordingStartedAt = Date()
    /// Set when the key went down while dictation wasn't available, so a
    /// deliberate hold can explain why on release.
    private var unavailablePressAt: Date?
    private var cleanupConfigTask: Task<Void, Never>?
    var cleanupMode: CleanupMode = .off

    private(set) var state: State = .setupRequired {
        didSet { onStateChange?(state) }
    }

    init() {
        audio.onLevel = { [weak self] level in
            self?.onLevel?(level)
        }
    }

    func startHotkeyMonitoring() {
        startHotkeyIfNeeded()
    }

    func restartHotkeyMonitoring() {
        // A hold in progress can't finish once the monitor is replaced.
        cancelRecording()
        hotkey.stop()
        hotkeyStarted = false
        startHotkeyIfNeeded()
    }

    func setHotkeyTrigger(_ trigger: HotkeyTrigger) {
        hotkey.trigger = trigger
    }

    func prepare(model: SpeechModelOption) {
        guard model.isSupportedInCurrentBuild else {
            state = .error("\(model.displayName) is not installed locally and has no downloadable model variant configured.")
            return
        }
        switch state {
        case .recording, .transcribing, .cleaning, .downloadingModel:
            return
        case .idle:
            // Already loaded; WhisperService returns immediately for the same model.
            break
        default:
            state = .downloadingModel(0)
        }

        startHotkeyMonitoring()

        Task { [weak self] in
            await self?.whisper.prepare(model: model) { [weak self] progress in
                Task { @MainActor in
                    guard let self, case .downloadingModel = self.state else { return }
                    self.state = .downloadingModel(progress)
                }
            }
            guard let self else { return }
            let result = await self.whisper.state
            // Only move on from loading states: if the model was already
            // loaded, a dictation may have started while this ran.
            switch self.state {
            case .downloadingModel, .warming:
                break
            default:
                return
            }
            switch result {
            case .ready:
                self.state = .idle
            case .failed(let msg):
                self.state = .error(msg)
            default:
                self.state = .warming
            }
        }
    }

    func markSetupRequired() {
        state = .setupRequired
    }

    private func startHotkeyIfNeeded() {
        guard !hotkeyStarted else { return }
        hotkeyStarted = true
        hotkey.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .pressed:
                self.hotkeyPressed()
            case .released:
                self.hotkeyReleased()
            case .cancelled:
                self.unavailablePressAt = nil
                self.cancelRecording()
            }
        }
        hotkey.start()
    }

    private func hotkeyPressed() {
        if case .idle = state {
            beginRecording()
        } else {
            unavailablePressAt = Date()
        }
    }

    private func hotkeyReleased() {
        if let pressedAt = unavailablePressAt {
            unavailablePressAt = nil
            if Date().timeIntervalSince(pressedAt) >= Self.minimumHold, let reason = unavailableReason {
                onNotice?(.notReady(reason))
            }
            return
        }
        endRecording()
    }

    private var unavailableReason: String? {
        switch state {
        case .setupRequired: return "Finish setting up NeelSpeak"
        case .downloadingModel, .warming: return "Speech model is still loading"
        case .error: return "NeelSpeak needs attention"
        case .idle, .recording, .transcribing, .cleaning: return nil
        }
    }

    private func beginRecording() {
        guard case .idle = state else { return }
        do {
            try audio.start()
            recordingStartedAt = Date()
            state = .recording
        } catch {
            onNotice?(.microphoneUnavailable)
        }
    }

    private func cancelRecording() {
        guard case .recording = state else { return }
        _ = audio.stopAndDrain()
        state = .idle
    }

    private func endRecording() {
        guard case .recording = state else { return }
        let samples = audio.stopAndDrain()
        guard Date().timeIntervalSince(recordingStartedAt) >= Self.minimumHold,
              samples.count >= Self.minimumSamples else {
            state = .idle
            return
        }
        state = .transcribing

        Task { [weak self] in
            guard let self else { return }
            let raw = await self.whisper.transcribe(samples: samples)
            let corrected = TranscriptCorrector.correct(raw)
            guard !corrected.isEmpty else {
                self.state = .idle
                self.onNotice?(.noSpeech)
                return
            }

            var text = corrected
            var issue: String?
            if self.cleanupMode != .off {
                self.state = .cleaning
                let cleaned = await self.cleaner.clean(TranscriptCorrector.removeHesitations(corrected), mode: self.cleanupMode)
                text = cleaned.text
                issue = cleaned.issue
            }

            TextInjector.inject(text)
            self.onResult?(DictationResult(
                text: text,
                rawText: text == corrected ? nil : corrected,
                cleanupIssue: issue,
                audioDuration: Double(samples.count) / 16_000
            ))
            self.state = .idle
            if issue != nil {
                self.onNotice?(.cleanupSkipped)
            }
        }
    }

    func setCleanupMode(_ mode: CleanupMode) {
        cleanupMode = mode
    }

    /// Applies cleanup settings to the cleaner and, when `connect` is set,
    /// checks the engine is usable. Calls are chained so settings always land
    /// in the order they were made.
    func configureCleanup(engine: CleanupEngine, config: LLMTranscriptCleaner.CloudConfig, connect: Bool) {
        let previous = cleanupConfigTask
        cleanupConfigTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await self.cleaner.setEngine(engine)
            await self.cleaner.setCloudConfig(config)
            if connect {
                await self.cleaner.prepare { _ in }
            }
            self.onCleanupState?(await self.cleaner.currentState())
        }
    }

    /// Runs cleanup on sample text with the current settings, for the settings window.
    func testCleanup(_ text: String, mode: CleanupMode) async -> LLMTranscriptCleaner.CleanupResult {
        await cleanupConfigTask?.value
        await cleaner.prepare { _ in }
        onCleanupState?(await cleaner.currentState())
        let corrected = TranscriptCorrector.removeHesitations(TranscriptCorrector.correct(text))
        return await cleaner.clean(corrected, mode: mode, allowShortcut: false)
    }

    func fetchCopilotModels() async -> [String] {
        // Let pending settings (e.g. the OAuth token at launch) land first.
        await cleanupConfigTask?.value
        return await cleaner.fetchCopilotModels()
    }
}
