import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import os
import ServiceManagement

private let settingsLog = Logger(subsystem: "com.neelspeak.app", category: "settings")

@MainActor
final class VoiceTyperViewModel: ObservableObject {
    enum UpdateStatus: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateChecker.Release)
        case failed
    }

    @Published private(set) var state: DictationCoordinator.State = .setupRequired
    @Published private(set) var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published private(set) var accessibilityTrusted: Bool = AXIsProcessTrusted()
    @Published var selectedModelID: String {
        didSet {
            UserDefaults.standard.set(selectedModelID, forKey: Self.selectedModelKey)
        }
    }
    @Published private(set) var setupComplete: Bool
    @Published private(set) var setupMessage: String?

    // MARK: General preferences

    @Published var hotkeyTrigger: HotkeyTrigger {
        didSet {
            UserDefaults.standard.set(hotkeyTrigger.rawValue, forKey: Self.hotkeyTriggerKey)
            coordinator.setHotkeyTrigger(hotkeyTrigger)
        }
    }
    @Published var soundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundsEnabled, forKey: Self.soundsEnabledKey)
            onSoundsChanged?(soundsEnabled)
        }
    }
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published private(set) var launchAtLoginError: String?

    // MARK: History

    @Published private(set) var history: [TranscriptEntry] = []
    @Published var keepHistory: Bool {
        didSet {
            UserDefaults.standard.set(keepHistory, forKey: Self.keepHistoryKey)
            guard !isSnapshot else { return }
            if keepHistory {
                TranscriptHistoryStore.save(history)
            } else {
                TranscriptHistoryStore.delete()
            }
        }
    }

    // MARK: Updates

    @Published var checkForUpdatesAutomatically: Bool {
        didSet {
            UserDefaults.standard.set(checkForUpdatesAutomatically, forKey: Self.checkForUpdatesKey)
        }
    }
    @Published private(set) var updateStatus: UpdateStatus = .idle

    // MARK: Cleanup

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
            cleanupState = .unloaded
            lastCleanupIssue = nil
            applyCleanupSettings(connect: cleanupMode != .off)
        }
    }
    @Published private(set) var cleanupState: LLMTranscriptCleaner.LoadState = .unloaded
    /// Why the most recent dictation was pasted without cleanup, if it was.
    @Published private(set) var lastCleanupIssue: String?
    @Published private(set) var cleanupTestResult: LLMTranscriptCleaner.CleanupResult?
    @Published private(set) var cleanupTestRunning = false

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
    /// Set when the keychain refused to store credentials.
    @Published private(set) var credentialStoreError: String?

    @Published var copilotDeviceCode: CopilotAuthService.DeviceCode?
    @Published var copilotAuthError: String?
    @Published var copilotAuthInProgress: Bool = false
    @Published private(set) var copilotAvailableModels: [String] = []
    @Published private(set) var copilotModelsLoading: Bool = false

    var onRetrySetup: (() -> Void)?
    var onPrepareModel: ((SpeechModelOption) -> Void)?
    var onHideWindow: (() -> Void)?
    var onSoundsChanged: ((Bool) -> Void)?

    private let coordinator: DictationCoordinator
    private let isSnapshot: Bool
    let themeStore: OverlayThemeStore
    private var savedCredentials = CredentialStore.Credentials()
    /// True when the keychain item exists but couldn't be read (e.g. access
    /// was denied after an update). Saves then merge instead of overwriting.
    private var credentialsUnreadable = false
    private var credentialSaveWork: DispatchWorkItem?
    private var copilotSignInTask: Task<Void, Never>?

    private static let selectedModelKey = "selectedModelID"
    private static let setupCompleteKey = "setupComplete"
    private static let hotkeyTriggerKey = "hotkeyTrigger"
    private static let soundsEnabledKey = "soundsEnabled"
    private static let keepHistoryKey = "keepHistory"
    private static let checkForUpdatesKey = "checkForUpdates"
    private static let lastUpdateCheckKey = "lastUpdateCheck"
    private static let cleanupModeKey = "cleanupMode"
    private static let cleanupEngineKey = "cleanupEngine"
    private static let cloudOpenAIBaseURLKey = "cloudOpenAIBaseURL"
    private static let cloudOpenAIModelKey = "cloudOpenAIModel"
    private static let cloudAnthropicModelKey = "cloudAnthropicModel"
    private static let cloudCopilotModelKey = "cloudCopilotModel"
    private static let anthropicDefaultMigratedKey = "anthropicDefaultModelMigrated"
    // Pre-1.0 builds kept secrets in UserDefaults; they now live in the keychain.
    private static let legacyOpenAIKeyKey = "cloudOpenAIKey"
    private static let legacyAnthropicKeyKey = "cloudAnthropicKey"
    private static let legacyCopilotOAuthTokenKey = "cloudCopilotOAuthToken"

    /// `isSnapshot` (debug UI rendering) leaves the keychain and history file untouched.
    init(coordinator: DictationCoordinator, themeStore: OverlayThemeStore, isSnapshot: Bool = false) {
        self.coordinator = coordinator
        self.isSnapshot = isSnapshot
        self.themeStore = themeStore
        let d = UserDefaults.standard
        selectedModelID = d.string(forKey: Self.selectedModelKey) ?? SpeechModelCatalog.defaultSelectionID
        setupComplete = d.bool(forKey: Self.setupCompleteKey)

        // Existing installs keep reacting to either Option key, as before 1.0;
        // new installs default to Right Option so Left Option stays free for typing.
        hotkeyTrigger = d.string(forKey: Self.hotkeyTriggerKey).flatMap(HotkeyTrigger.init(rawValue:))
            ?? (d.bool(forKey: Self.setupCompleteKey) ? .eitherOption : .rightOption)
        soundsEnabled = d.bool(forKey: Self.soundsEnabledKey)
        keepHistory = d.object(forKey: Self.keepHistoryKey) as? Bool ?? true
        checkForUpdatesAutomatically = d.object(forKey: Self.checkForUpdatesKey) as? Bool ?? true

        let storedMode = d.string(forKey: Self.cleanupModeKey).flatMap(CleanupMode.init(rawValue:)) ?? .off
        let storedEngine = d.string(forKey: Self.cleanupEngineKey).flatMap(CleanupEngine.init(rawValue:)) ?? .foundationModels
        cleanupMode = storedMode
        cleanupEngine = storedEngine

        cloudOpenAIBaseURL = d.string(forKey: Self.cloudOpenAIBaseURLKey) ?? OpenAICompatPreset.githubModels.baseURL
        cloudOpenAIModel = d.string(forKey: Self.cloudOpenAIModelKey) ?? OpenAICompatPreset.githubModels.defaultModel
        var anthropicModel = d.string(forKey: Self.cloudAnthropicModelKey) ?? LLMTranscriptCleaner.CloudConfig.defaultAnthropicModel
        if !d.bool(forKey: Self.anthropicDefaultMigratedKey) {
            // claude-haiku-4-5 was the pre-1.0 default rather than a deliberate choice.
            if anthropicModel == "claude-haiku-4-5" { anthropicModel = LLMTranscriptCleaner.CloudConfig.defaultAnthropicModel }
            d.set(true, forKey: Self.anthropicDefaultMigratedKey)
        }
        cloudAnthropicModel = anthropicModel
        cloudCopilotModel = d.string(forKey: Self.cloudCopilotModelKey) ?? "gpt-4o-mini"

        let credentials = isSnapshot ? (value: CredentialStore.Credentials(), error: nil) : Self.loadCredentials()
        savedCredentials = credentials.value
        credentialStoreError = credentials.error
        credentialsUnreadable = credentials.error != nil
        cloudOpenAIKey = credentials.value.openAIKey
        cloudAnthropicKey = credentials.value.anthropicKey
        cloudCopilotOAuthToken = credentials.value.copilotOAuthToken

        if keepHistory && !isSnapshot {
            history = TranscriptHistoryStore.load()
        }

        coordinator.setHotkeyTrigger(hotkeyTrigger)
        coordinator.setCleanupMode(storedMode)
        applyCleanupSettings(connect: storedMode != .off)
        refreshLaunchAtLogin()

        // If we already have a Copilot OAuth token, pre-fetch the available
        // models so the picker is populated by the time the user opens it.
        if !cloudCopilotOAuthToken.isEmpty {
            Task { @MainActor [weak self] in self?.refreshCopilotModels() }
        }
    }

    // MARK: - Credentials

    /// Reads credentials from the keychain, moving any pre-1.0 plaintext
    /// copies out of UserDefaults on the way.
    private static func loadCredentials() -> (value: CredentialStore.Credentials, error: String?) {
        let d = UserDefaults.standard
        let legacy = CredentialStore.Credentials(
            openAIKey: d.string(forKey: legacyOpenAIKeyKey) ?? "",
            anthropicKey: d.string(forKey: legacyAnthropicKeyKey) ?? "",
            copilotOAuthToken: d.string(forKey: legacyCopilotOAuthTokenKey) ?? ""
        )
        do {
            if let stored = try CredentialStore.load() {
                removeLegacyCredentials()
                return (stored, nil)
            }
            guard !legacy.isEmpty else { return (legacy, nil) }
            try CredentialStore.save(legacy)
            removeLegacyCredentials()
            settingsLog.info("Moved cleanup credentials from UserDefaults to the keychain")
            return (legacy, nil)
        } catch {
            settingsLog.error("Keychain unavailable: \(String(describing: error), privacy: .public)")
            return (legacy, String(describing: error))
        }
    }

    private static func removeLegacyCredentials() {
        let d = UserDefaults.standard
        for key in [legacyOpenAIKeyKey, legacyAnthropicKeyKey, legacyCopilotOAuthTokenKey] {
            d.removeObject(forKey: key)
        }
    }

    private var currentCredentials: CredentialStore.Credentials {
        CredentialStore.Credentials(
            openAIKey: cloudOpenAIKey,
            anthropicKey: cloudAnthropicKey,
            copilotOAuthToken: cloudCopilotOAuthToken
        )
    }

    /// Debounced so typing a key doesn't write the keychain on every keystroke.
    private func scheduleCredentialSave() {
        credentialSaveWork?.cancel()
        credentialSaveWork = nil
        let credentials = currentCredentials
        guard credentials != savedCredentials else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                var toSave = credentials
                if self.credentialsUnreadable {
                    // Never overwrite secrets we couldn't read: keep what's stored
                    // and apply only the fields entered this session.
                    let stored = try CredentialStore.load() ?? CredentialStore.Credentials()
                    toSave = CredentialStore.Credentials(
                        openAIKey: credentials.openAIKey.isEmpty ? stored.openAIKey : credentials.openAIKey,
                        anthropicKey: credentials.anthropicKey.isEmpty ? stored.anthropicKey : credentials.anthropicKey,
                        copilotOAuthToken: credentials.copilotOAuthToken.isEmpty ? stored.copilotOAuthToken : credentials.copilotOAuthToken
                    )
                    self.credentialsUnreadable = false
                }
                try CredentialStore.save(toSave)
                self.savedCredentials = toSave
                self.credentialStoreError = nil
                if toSave != credentials {
                    self.cloudOpenAIKey = toSave.openAIKey
                    self.cloudAnthropicKey = toSave.anthropicKey
                    self.cloudCopilotOAuthToken = toSave.copilotOAuthToken
                }
            } catch {
                self.credentialStoreError = String(describing: error)
            }
        }
        credentialSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func saveCloudConfig() {
        let d = UserDefaults.standard
        d.set(cloudOpenAIBaseURL, forKey: Self.cloudOpenAIBaseURLKey)
        d.set(cloudOpenAIModel, forKey: Self.cloudOpenAIModelKey)
        d.set(cloudAnthropicModel, forKey: Self.cloudAnthropicModelKey)
        d.set(cloudCopilotModel, forKey: Self.cloudCopilotModelKey)
        scheduleCredentialSave()
        applyCleanupSettings(connect: cleanupMode != .off)
    }

    /// Sends engine and provider settings to the cleaner in one ordered step.
    private func applyCleanupSettings(connect: Bool) {
        if connect, cleanupState != .ready { cleanupState = .loading }
        coordinator.configureCleanup(engine: cleanupEngine, config: cloudConfig, connect: connect)
    }

    private var cloudConfig: LLMTranscriptCleaner.CloudConfig {
        var config = LLMTranscriptCleaner.CloudConfig()
        config.openAIBaseURL = cloudOpenAIBaseURL
        config.openAIModel = cloudOpenAIModel
        config.openAIKey = cloudOpenAIKey
        config.anthropicModel = cloudAnthropicModel
        config.anthropicKey = cloudAnthropicKey
        config.copilotModel = cloudCopilotModel
        config.copilotOAuthToken = cloudCopilotOAuthToken
        return config
    }

    // MARK: - GitHub Copilot

    /// Start the GitHub Copilot device-flow login. Publishes the device code so
    /// the view can show the user code + verification URL.
    func startCopilotSignIn() {
        guard !copilotAuthInProgress else { return }
        copilotAuthInProgress = true
        copilotAuthError = nil
        copilotDeviceCode = nil
        copilotSignInTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let code = try await CopilotAuthService.requestDeviceCode()
                self.copilotDeviceCode = code
                // Auto-open browser to make the flow one-click
                if let url = URL(string: code.verificationURL) {
                    NSWorkspace.shared.open(url)
                }
                let token = try await CopilotAuthService.pollForOAuthToken(deviceCode: code)
                guard !Task.isCancelled else { return }
                self.cloudCopilotOAuthToken = token
                self.copilotDeviceCode = nil
                self.copilotAuthInProgress = false
                self.refreshCopilotModels()
            } catch {
                guard !Task.isCancelled else { return }
                self.copilotAuthError = String(describing: error)
                self.copilotDeviceCode = nil
                self.copilotAuthInProgress = false
            }
        }
    }

    func cancelCopilotSignIn() {
        copilotSignInTask?.cancel()
        copilotSignInTask = nil
        copilotDeviceCode = nil
        copilotAuthInProgress = false
    }

    func signOutOfCopilot() {
        cancelCopilotSignIn()
        cloudCopilotOAuthToken = ""
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

    // MARK: - Cleanup state

    var cleanupReady: Bool {
        if case .ready = cleanupState { return true }
        return false
    }

    var cleanupStatusLabel: String {
        if cleanupMode == .off { return "Off" }
        switch cleanupState {
        case .unloaded: return "Not connected"
        case .loading: return "Connecting…"
        case .ready: return "Ready"
        case .unsupported: return "Needs setup"
        case .failed: return "Error"
        }
    }

    var cleanupProblem: String? {
        guard cleanupMode != .off else { return nil }
        switch cleanupState {
        case .unsupported(let message), .failed(let message):
            return message
        default:
            return lastCleanupIssue
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
        applyCleanupSettings(connect: true)
    }

    func updateCleanupState(_ state: LLMTranscriptCleaner.LoadState) {
        cleanupState = state
    }

    func ensureCleanupModelReady() {
        if case .ready = cleanupState { return }
        applyCleanupSettings(connect: true)
    }

    func testCleanup(_ text: String) {
        guard !cleanupTestRunning else { return }
        cleanupTestRunning = true
        cleanupTestResult = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.coordinator.testCleanup(text, mode: self.cleanupMode == .off ? .conservative : self.cleanupMode)
            self.cleanupTestResult = result
            self.cleanupTestRunning = false
        }
    }

    // MARK: - Dictation state

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var microphoneLabel: String {
        switch microphoneStatus {
        case .authorized:
            return "Allowed"
        case .notDetermined:
            return "Not requested yet"
        case .denied:
            return "Denied — allow it in System Settings"
        case .restricted:
            return "Restricted by your administrator"
        @unknown default:
            return "Unknown"
        }
    }

    var accessibilityLabel: String {
        accessibilityTrusted ? "Allowed" : "Required for the shortcut and pasting"
    }

    var permissionsGranted: Bool {
        microphoneStatus == .authorized && accessibilityTrusted
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
        switch state {
        case .idle, .recording, .transcribing, .cleaning:
            return true
        default:
            return false
        }
    }

    var needsSetup: Bool {
        !setupComplete || !permissionsGranted || !modelReady
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    func update(state: DictationCoordinator.State) {
        self.state = state
        if case .idle = state {
            setupMessage = nil
        }
    }

    // MARK: - History

    func record(_ result: DictationResult) {
        lastCleanupIssue = result.cleanupIssue
        history.insert(TranscriptEntry(result: result), at: 0)
        if history.count > TranscriptHistoryStore.limit {
            history.removeLast(history.count - TranscriptHistoryStore.limit)
        }
        if keepHistory {
            if !isSnapshot { TranscriptHistoryStore.save(history) }
        } else if history.count > 20 {
            history.removeLast(history.count - 20)
        }
    }

    func copy(_ entry: TranscriptEntry) {
        TextInjector.copyToClipboard(entry.text)
    }

    func copyLastDictation() {
        guard let latest = history.first else { return }
        copy(latest)
    }

    func delete(_ entry: TranscriptEntry) {
        history.removeAll { $0.id == entry.id }
        if keepHistory && !isSnapshot { TranscriptHistoryStore.save(history) }
    }

    func clearHistory() {
        history = []
        if !isSnapshot { TranscriptHistoryStore.delete() }
    }

    // MARK: - Launch at login

    func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        launchAtLoginNeedsApproval = status == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Updates

    /// Checks GitHub for a newer release. Automatic checks run at most once a day.
    func checkForUpdates(userInitiated: Bool) {
        if case .checking = updateStatus { return }
        if !userInitiated {
            guard checkForUpdatesAutomatically else { return }
            let last = UserDefaults.standard.object(forKey: Self.lastUpdateCheckKey) as? Date ?? .distantPast
            guard Date().timeIntervalSince(last) > 20 * 60 * 60 else { return }
        }
        updateStatus = .checking
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let release = try await UpdateChecker.newerRelease()
                UserDefaults.standard.set(Date(), forKey: Self.lastUpdateCheckKey)
                self.updateStatus = release.map(UpdateStatus.available) ?? .upToDate
            } catch {
                settingsLog.error("Update check failed: \(error.localizedDescription, privacy: .public)")
                self.updateStatus = .failed
            }
        }
    }

    var availableUpdate: UpdateChecker.Release? {
        if case .available(let release) = updateStatus { return release }
        return nil
    }

    func openUpdatePage() {
        NSWorkspace.shared.open(availableUpdate?.pageURL ?? UpdateChecker.releasesPage)
    }

    // MARK: - Setup

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

    func requestAccessibilityPermission() {
        // Registers NeelSpeak in the Accessibility list and shows the system prompt.
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        if !AXIsProcessTrustedWithOptions(options) {
            openAccessibilitySettings()
        }
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
