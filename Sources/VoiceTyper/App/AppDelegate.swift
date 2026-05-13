import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private var coordinator: DictationCoordinator!
    private var viewModel: VoiceTyperViewModel!
    private var mainWindow: MainWindowController!
    private var listeningOverlay: ListeningOverlayController!
    private var themeStore: OverlayThemeStore!
    private var permissionRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        themeStore = OverlayThemeStore()
        coordinator = DictationCoordinator()
        viewModel = VoiceTyperViewModel(coordinator: coordinator, themeStore: themeStore)
        mainWindow = MainWindowController(viewModel: viewModel)
        listeningOverlay = ListeningOverlayController(themeStore: themeStore)
        statusBar = StatusBarController()

        coordinator.onStateChange = { [weak self] state in
            self?.statusBar.update(state: state)
            self?.viewModel.update(state: state)
            self?.listeningOverlay.update(state: state)
        }
        coordinator.onHotkeyEvent = { [weak self] event in
            self?.listeningOverlay.update(hotkeyEvent: event)
        }
        coordinator.onTranscript = { [weak self] text in
            self?.viewModel.addTranscript(text)
        }
        statusBar.onOpenWindow = { [weak self] in
            self?.showMainWindow()
        }
        statusBar.onRetrySetup = { [weak self] in
            self?.showMainWindow()
            self?.viewModel.resetSetup()
        }
        viewModel.onRetrySetup = { [weak self] in
            self?.startIfReady()
        }
        viewModel.onPrepareModel = { [weak self] model in
            self?.coordinator.prepare(model: model)
        }
        viewModel.onHideWindow = { [weak self] in
            self?.mainWindow.hide()
        }
        viewModel.onPrepareCleanupModel = { [weak self] in
            self?.coordinator.prepareCleanupModel()
        }
        coordinator.onCleanupState = { [weak self] state in
            self?.viewModel.updateCleanupState(state)
        }
        if viewModel.cleanupMode != .off {
            coordinator.prepareCleanupModel()
        }

        statusBar.update(state: .setupRequired)
        coordinator.startHotkeyMonitoring()
        startPermissionRefreshTimer()
        if viewModel.setupComplete {
            startIfReady()
        } else {
            showMainWindow()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        viewModel.refreshPermissions()
        if viewModel.setupComplete {
            startIfReady()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionRefreshTimer?.invalidate()
    }

    private func showMainWindow() {
        mainWindow.show()
        viewModel.refreshPermissions()
    }

    private func startIfReady() {
        viewModel.refreshPermissions()
        guard viewModel.microphoneStatus == .authorized else {
            coordinator.markSetupRequired()
            if !viewModel.setupComplete { showMainWindow() }
            return
        }
        checkAccessibility(prompt: !viewModel.setupComplete)
        viewModel.refreshPermissions()
        guard viewModel.accessibilityTrusted else {
            coordinator.markSetupRequired()
            if !viewModel.setupComplete { showMainWindow() }
            return
        }
        coordinator.prepare(model: viewModel.selectedModel)
    }

    private func checkAccessibility(prompt: Bool) {
        // Prompts the user to grant Accessibility access if missing.
        // Required for global hotkey monitoring and synthetic Cmd+V.
        let opts: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ]
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let wasReady = self.viewModel.microphoneStatus == .authorized && self.viewModel.accessibilityTrusted
                let wasAccessibilityTrusted = self.viewModel.accessibilityTrusted
                self.viewModel.refreshPermissions()
                let isReady = self.viewModel.microphoneStatus == .authorized && self.viewModel.accessibilityTrusted
                if !wasAccessibilityTrusted && self.viewModel.accessibilityTrusted {
                    self.coordinator.restartHotkeyMonitoring()
                }
                if !wasReady && isReady && self.viewModel.setupComplete {
                    self.startIfReady()
                }
            }
        }
    }
}
