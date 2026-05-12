import AppKit
import ApplicationServices
import AVFoundation
import Foundation

@MainActor
final class VoiceTyperViewModel: ObservableObject {
    struct TranscriptEntry: Identifiable {
        let id = UUID()
        let text: String
        let date: Date
    }

    @Published private(set) var state: DictationCoordinator.State = .setupRequired
    @Published private(set) var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published private(set) var accessibilityTrusted: Bool = AXIsProcessTrusted()
    @Published private(set) var recentTranscripts: [TranscriptEntry] = []
    @Published var selectedModelID: String {
        didSet {
            UserDefaults.standard.set(selectedModelID, forKey: Self.selectedModelKey)
        }
    }
    @Published private(set) var setupComplete: Bool
    @Published private(set) var setupMessage: String?

    var onRetrySetup: (() -> Void)?
    var onPrepareModel: ((SpeechModelOption) -> Void)?
    var onHideWindow: (() -> Void)?

    private let coordinator: DictationCoordinator
    let themeStore: OverlayThemeStore
    private static let selectedModelKey = "selectedModelID"
    private static let setupCompleteKey = "setupComplete"

    init(coordinator: DictationCoordinator, themeStore: OverlayThemeStore) {
        self.coordinator = coordinator
        self.themeStore = themeStore
        selectedModelID = UserDefaults.standard.string(forKey: Self.selectedModelKey)
            ?? SpeechModelCatalog.defaultSelectionID
        setupComplete = UserDefaults.standard.bool(forKey: Self.setupCompleteKey)
    }

    var canStartRecording: Bool {
        if case .idle = state { return true }
        return false
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var microphoneLabel: String {
        switch microphoneStatus {
        case .authorized:
            return "Allowed"
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        @unknown default:
            return "Unknown"
        }
    }

    var accessibilityLabel: String {
        accessibilityTrusted ? "Allowed" : "Required"
    }

    var selectedModel: SpeechModelOption {
        SpeechModelCatalog.option(id: selectedModelID)
    }

    var modelProgress: Double? {
        if case .downloadingModel(let progress) = state {
            return progress
        }
        return nil
    }

    var modelReady: Bool {
        if case .idle = state { return true }
        if case .recording = state { return true }
        if case .transcribing = state { return true }
        return false
    }

    var needsSetup: Bool {
        !setupComplete || microphoneStatus != .authorized || !accessibilityTrusted || !modelReady
    }

    func update(state: DictationCoordinator.State) {
        self.state = state
        if case .idle = state {
            setupMessage = nil
        }
    }

    func addTranscript(_ text: String) {
        let entry = TranscriptEntry(text: text, date: Date())
        recentTranscripts.insert(entry, at: 0)
        if recentTranscripts.count > 8 {
            recentTranscripts.removeLast(recentTranscripts.count - 8)
        }
    }

    func beginDictation() {
        coordinator.beginDictation()
    }

    func endDictation() {
        coordinator.endDictation()
    }

    func retrySetup() {
        refreshPermissions()
        onRetrySetup?()
    }

    func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            refreshPermissions()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshPermissions()
                }
            }
        default:
            openMicrophoneSettings()
        }
    }

    func chooseCurrentBuildFallbackModel() {
        selectedModelID = SpeechModelCatalog.currentBuildFallbackID
        setupMessage = nil
    }

    func prepareSelectedModel() {
        let model = selectedModel
        guard model.isSupportedInCurrentBuild else {
            setupMessage = "\(model.displayName) cannot be used in this build."
            return
        }
        setupMessage = nil
        onPrepareModel?(model)
    }

    func finishSetupAndRunInBackground() {
        setupComplete = true
        UserDefaults.standard.set(true, forKey: Self.setupCompleteKey)
        onHideWindow?()
    }

    func resetSetup() {
        setupComplete = false
        UserDefaults.standard.set(false, forKey: Self.setupCompleteKey)
    }

    func refreshPermissions() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityTrusted = AXIsProcessTrusted()
    }

    func openMicrophoneSettings() {
        openPrivacyPane(anchor: "Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    private func openPrivacyPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
