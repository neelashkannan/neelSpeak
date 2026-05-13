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
    @Published var cleanupMode: CleanupMode {
        didSet {
            UserDefaults.standard.set(cleanupMode.rawValue, forKey: Self.cleanupModeKey)
            coordinator.setCleanupMode(cleanupMode)
            if cleanupMode != .off {
                ensureCleanupModelReady()
            }
        }
    }
    @Published var cleanupEngine: CleanupEngine {
        didSet {
            UserDefaults.standard.set(cleanupEngine.rawValue, forKey: Self.cleanupEngineKey)
            coordinator.setCleanupEngine(cleanupEngine)
            cleanupState = .unloaded
            if cleanupMode != .off {
                ensureCleanupModelReady()
            }
        }
    }
    @Published private(set) var cleanupState: LLMTranscriptCleaner.LoadState = .unloaded

    @Published var cloudOpenAIBaseURL: String {
        didSet { saveCloudConfig() }
    }
    @Published var cloudOpenAIModel: String {
        didSet { saveCloudConfig() }
    }
    @Published var cloudOpenAIKey: String {
        didSet { saveCloudConfig() }
    }
    @Published var cloudAnthropicModel: String {
        didSet { saveCloudConfig() }
    }
    @Published var cloudAnthropicKey: String {
        didSet { saveCloudConfig() }
    }
    @Published var cloudCopilotModel: String {
        didSet { saveCloudConfig() }
    }
    @Published var cloudCopilotOAuthToken: String {
        didSet { saveCloudConfig() }
    }

    @Published var copilotDeviceCode: CopilotAuthService.DeviceCode?
    @Published var copilotAuthError: String?
    @Published var copilotAuthInProgress: Bool = false
    @Published private(set) var copilotAvailableModels: [String] = []
    @Published private(set) var copilotModelsLoading: Bool = false

    var onRetrySetup: (() -> Void)?
    var onPrepareModel: ((SpeechModelOption) -> Void)?
    var onHideWindow: (() -> Void)?
    var onPrepareCleanupModel: (() -> Void)?

    private let coordinator: DictationCoordinator
    let themeStore: OverlayThemeStore
    private static let selectedModelKey = "selectedModelID"
    private static let setupCompleteKey = "setupComplete"
    private static let cleanupModeKey = "cleanupMode"
    private static let cleanupEngineKey = "cleanupEngine"
    private static let cloudOpenAIBaseURLKey = "cloudOpenAIBaseURL"
    private static let cloudOpenAIModelKey = "cloudOpenAIModel"
    private static let cloudOpenAIKeyKey = "cloudOpenAIKey"
    private static let cloudAnthropicModelKey = "cloudAnthropicModel"
    private static let cloudAnthropicKeyKey = "cloudAnthropicKey"
    private static let cloudCopilotModelKey = "cloudCopilotModel"
    private static let cloudCopilotOAuthTokenKey = "cloudCopilotOAuthToken"

    init(coordinator: DictationCoordinator, themeStore: OverlayThemeStore) {
        self.coordinator = coordinator
        self.themeStore = themeStore
        selectedModelID = UserDefaults.standard.string(forKey: Self.selectedModelKey)
            ?? SpeechModelCatalog.defaultSelectionID
        setupComplete = UserDefaults.standard.bool(forKey: Self.setupCompleteKey)
        let storedMode = UserDefaults.standard.string(forKey: Self.cleanupModeKey)
            .flatMap(CleanupMode.init(rawValue:)) ?? .off
        let storedEngine = UserDefaults.standard.string(forKey: Self.cleanupEngineKey)
            .flatMap(CleanupEngine.init(rawValue:)) ?? .foundationModels
        self.cleanupMode = storedMode
        self.cleanupEngine = storedEngine

        let d = UserDefaults.standard
        self.cloudOpenAIBaseURL = d.string(forKey: Self.cloudOpenAIBaseURLKey) ?? OpenAICompatPreset.githubModels.baseURL
        self.cloudOpenAIModel = d.string(forKey: Self.cloudOpenAIModelKey) ?? OpenAICompatPreset.githubModels.defaultModel
        self.cloudOpenAIKey = d.string(forKey: Self.cloudOpenAIKeyKey) ?? ""
        self.cloudAnthropicModel = d.string(forKey: Self.cloudAnthropicModelKey) ?? "claude-haiku-4-5"
        self.cloudAnthropicKey = d.string(forKey: Self.cloudAnthropicKeyKey) ?? ""
        self.cloudCopilotModel = d.string(forKey: Self.cloudCopilotModelKey) ?? "gpt-4o-mini"
        self.cloudCopilotOAuthToken = d.string(forKey: Self.cloudCopilotOAuthTokenKey) ?? ""

        coordinator.setCleanupMode(storedMode)
        coordinator.setCleanupEngine(storedEngine)
        pushCloudConfigToCoordinator()

        // If we already have a Copilot OAuth token on disk, pre-fetch the
        // available models so the picker is populated by the time the user
        // opens the cleanup card.
        if !cloudCopilotOAuthToken.isEmpty {
            Task { @MainActor [weak self] in self?.refreshCopilotModels() }
        }
    }

    private func saveCloudConfig() {
        let d = UserDefaults.standard
        d.set(cloudOpenAIBaseURL, forKey: Self.cloudOpenAIBaseURLKey)
        d.set(cloudOpenAIModel, forKey: Self.cloudOpenAIModelKey)
        d.set(cloudOpenAIKey, forKey: Self.cloudOpenAIKeyKey)
        d.set(cloudAnthropicModel, forKey: Self.cloudAnthropicModelKey)
        d.set(cloudAnthropicKey, forKey: Self.cloudAnthropicKeyKey)
        d.set(cloudCopilotModel, forKey: Self.cloudCopilotModelKey)
        d.set(cloudCopilotOAuthToken, forKey: Self.cloudCopilotOAuthTokenKey)
        pushCloudConfigToCoordinator()
        if cleanupEngine.isCloud && cleanupMode != .off {
            ensureCleanupModelReady()
        }
    }

    private func pushCloudConfigToCoordinator() {
        var config = LLMTranscriptCleaner.CloudConfig()
        config.openAIBaseURL = cloudOpenAIBaseURL
        config.openAIModel = cloudOpenAIModel
        config.openAIKey = cloudOpenAIKey
        config.anthropicModel = cloudAnthropicModel
        config.anthropicKey = cloudAnthropicKey
        config.copilotModel = cloudCopilotModel
        config.copilotOAuthToken = cloudCopilotOAuthToken
        coordinator.setCleanupCloudConfig(config)
    }

    /// Start the GitHub Copilot device-flow login. Returns the device code so
    /// the view can show the user code + verification URL.
    func startCopilotSignIn() {
        guard !copilotAuthInProgress else { return }
        copilotAuthInProgress = true
        copilotAuthError = nil
        copilotDeviceCode = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let code = try await CopilotAuthService.requestDeviceCode()
                self.copilotDeviceCode = code
                // Auto-open browser to make the flow one-click
                if let url = URL(string: code.verificationURL) {
                    NSWorkspace.shared.open(url)
                }
                let token = try await CopilotAuthService.pollForOAuthToken(deviceCode: code)
                self.cloudCopilotOAuthToken = token
                self.copilotDeviceCode = nil
                self.copilotAuthInProgress = false
                self.refreshCopilotModels()
            } catch {
                self.copilotAuthError = String(describing: error)
                self.copilotDeviceCode = nil
                self.copilotAuthInProgress = false
            }
        }
    }

    func signOutOfCopilot() {
        cloudCopilotOAuthToken = ""
        copilotDeviceCode = nil
        copilotAuthError = nil
        copilotAvailableModels = []
    }

    func refreshCopilotModels() {
        guard !cloudCopilotOAuthToken.isEmpty else { return }
        copilotModelsLoading = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let models = await self.coordinator.fetchCopilotModels()
            self.copilotAvailableModels = models
            self.copilotModelsLoading = false
            // If the user's saved model isn't in the list, fall back to the first available.
            if !models.isEmpty && !models.contains(self.cloudCopilotModel) {
                self.cloudCopilotModel = models.first ?? self.cloudCopilotModel
            }
        }
    }

    func applyOpenAIPreset(_ preset: OpenAICompatPreset) {
        guard preset.id != "custom" else { return }
        cloudOpenAIBaseURL = preset.baseURL
        cloudOpenAIModel = preset.defaultModel
    }

    var cleanupReady: Bool {
        if case .ready = cleanupState { return true }
        return false
    }

    var cleanupStatusLabel: String {
        switch cleanupState {
        case .unloaded:
            return cleanupMode == .off ? "Off" : "Not loaded"
        case .loading:
            return "Loading…"
        case .ready:
            return "Ready"
        case .unsupported:
            return "Unavailable"
        case .failed(let msg):
            return "Error: \(msg.prefix(80))"
        }
    }

    var cleanupActionLabel: String {
        switch cleanupEngine {
        case .foundationModels:
            return "Check Apple Intelligence"
        case .githubCopilot:
            return "Sign in to GitHub Copilot"
        case .openAICompatible:
            return "Connect OpenAI-compatible API"
        case .anthropic:
            return "Connect Anthropic API"
        }
    }

    var cleanupCanLoad: Bool {
        switch cleanupState {
        case .loading, .ready:
            return false
        default:
            return true
        }
    }

    func loadCleanupModelNow() {
        onPrepareCleanupModel?()
    }

    func updateCleanupState(_ state: LLMTranscriptCleaner.LoadState) {
        cleanupState = state
    }

    func ensureCleanupModelReady() {
        switch cleanupState {
        case .ready, .loading:
            return
        default:
            onPrepareCleanupModel?()
        }
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
        if case .cleaning = state { return true }
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
