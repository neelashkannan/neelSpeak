import AppKit
import Foundation

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

    var onStateChange: ((State) -> Void)?
    var onTranscript: ((String) -> Void)?
    var onHotkeyEvent: ((HotkeyManager.Event) -> Void)?
    var onCleanupState: ((LLMTranscriptCleaner.LoadState) -> Void)?

    private let audio = AudioEngine()
    private let hotkey = HotkeyManager()
    private let whisper = WhisperService()
    private let cleaner = LLMTranscriptCleaner()
    private var hotkeyStarted = false
    var cleanupMode: CleanupMode = .off

    private(set) var state: State = .setupRequired {
        didSet { onStateChange?(state) }
    }

    func startHotkeyMonitoring() {
        startHotkeyIfNeeded()
    }

    func restartHotkeyMonitoring() {
        hotkey.stop()
        hotkeyStarted = false
        startHotkeyIfNeeded()
    }

    func prepare(model: SpeechModelOption) {
        guard model.isSupportedInCurrentBuild else {
            state = .error("\(model.displayName) is not installed locally and has no downloadable model variant configured.")
            return
        }
        if case .recording = state { return }
        if case .transcribing = state { return }
        if case .downloadingModel = state { return }
        state = .downloadingModel(0)

        startHotkeyMonitoring()

        Task { [weak self] in
            await self?.whisper.prepare(model: model) { [weak self] progress in
                Task { @MainActor in
                    self?.state = .downloadingModel(progress)
                }
            }
            let s = await self?.whisper.state
            await MainActor.run {
                guard let self else { return }
                if case .ready = s {
                    self.state = .idle
                } else if case .failed(let msg) = s {
                    self.state = .error(msg)
                } else {
                    self.state = .warming
                }
            }
        }
    }

    func beginDictation() {
        beginRecording()
    }

    func endDictation() {
        endRecording()
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
                self.onHotkeyEvent?(.pressed)
                self.beginRecording()
            case .released:
                self.endRecording()
                self.onHotkeyEvent?(.released)
            }
        }
        hotkey.start()
    }

    private func beginRecording() {
        guard case .idle = state else { return }
        do {
            try audio.start()
            state = .recording
        } catch {
            state = .error("mic: \(error.localizedDescription)")
        }
    }

    private func endRecording() {
        guard case .recording = state else { return }
        let samples = audio.stopAndDrain()
        state = .transcribing

        Task { [weak self] in
            guard let self else { return }
            let raw = await self.whisper.transcribe(samples: samples)
            let corrected = TranscriptCorrector.correct(raw)
            let mode = self.cleanupMode
            let cleaned: String
            if mode == .off || corrected.isEmpty {
                cleaned = corrected
            } else {
                await MainActor.run { self.state = .cleaning }
                cleaned = await self.cleaner.clean(corrected, mode: mode)
            }
            await MainActor.run {
                if !cleaned.isEmpty {
                    self.onTranscript?(cleaned)
                    TextInjector.inject(cleaned)
                }
                self.state = .idle
            }
        }
    }

    func setCleanupMode(_ mode: CleanupMode) {
        cleanupMode = mode
    }

    func setCleanupEngine(_ engine: CleanupEngine) {
        Task { [weak self] in
            guard let self else { return }
            await self.cleaner.setEngine(engine)
            await MainActor.run {
                self.onCleanupState?(.unloaded)
            }
        }
    }

    func setCleanupCloudConfig(_ config: LLMTranscriptCleaner.CloudConfig) {
        Task { [weak self] in
            await self?.cleaner.setCloudConfig(config)
        }
    }

    func fetchCopilotModels() async -> [String] {
        await cleaner.fetchCopilotModels()
    }

    func prepareCleanupModel() {
        Task { [weak self] in
            guard let self else { return }
            await self.cleaner.prepare { _ in }
            let s = await self.cleaner.currentState()
            await MainActor.run {
                self.onCleanupState?(s)
            }
        }
    }

    func unloadCleanupModel() {
        Task { [weak self] in
            await self?.cleaner.unload()
            await MainActor.run {
                self?.onCleanupState?(.unloaded)
            }
        }
    }
}
