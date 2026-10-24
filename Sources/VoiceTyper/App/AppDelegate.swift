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
    private let sounds = SoundFeedback()
    private var permissionRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        themeStore = OverlayThemeStore()
        coordinator = DictationCoordinator()
        viewModel = VoiceTyperViewModel(coordinator: coordinator, themeStore: themeStore)
        mainWindow = MainWindowController(viewModel: viewModel)
        listeningOverlay = ListeningOverlayController(themeStore: themeStore)
        statusBar = StatusBarController(viewModel: viewModel)
        sounds.isEnabled = viewModel.soundsEnabled
        NSApp.mainMenu = makeMainMenu()

        coordinator.onStateChange = { [weak self] state in
            guard let self else { return }
            self.statusBar.update(state: state)
            self.viewModel.update(state: state)
            self.listeningOverlay.update(state: state)
            self.sounds.update(state: state)
        }
        coordinator.onLevel = { [weak self] level in
            self?.listeningOverlay.update(level: level)
        }
        coordinator.onNotice = { [weak self] notice in
            self?.listeningOverlay.show(notice: notice)
        }
        coordinator.onResult = { [weak self] result in
            self?.viewModel.record(result)
        }
        coordinator.onCleanupState = { [weak self] state in
            self?.viewModel.updateCleanupState(state)
        }
        statusBar.onOpenWindow = { [weak self] in
            self?.showMainWindow()
        }
        statusBar.onOpenSettings = { [weak self] in
            self?.showMainWindow(section: .general)
        }
        statusBar.onRetrySetup = { [weak self] in
            self?.showMainWindow(section: .general)
            self?.viewModel.retrySetup()
        }
        statusBar.onShowAbout = { [weak self] in
            self?.showAbout()
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
        viewModel.onSoundsChanged = { [weak self] enabled in
            self?.sounds.isEnabled = enabled
        }

        statusBar.update(state: .setupRequired)
        coordinator.startHotkeyMonitoring()
        startPermissionRefreshTimer()
        if viewModel.setupComplete {
            startIfReady()
        } else {
            showMainWindow()
        }
        viewModel.checkForUpdates(userInitiated: false)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        viewModel.refreshPermissions()
        viewModel.refreshLaunchAtLogin()
        if viewModel.setupComplete {
            startIfReady()
        }
    }

    /// Opening NeelSpeak again from Finder or Spotlight shows the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionRefreshTimer?.invalidate()
    }

    private func showMainWindow(section: DashboardSection? = nil) {
        mainWindow.show(section: section)
        viewModel.refreshPermissions()
    }

    @objc private func showSettings() {
        showMainWindow(section: .general)
    }

    @objc private func showAbout() {
        let credits = NSAttributedString(
            string: "Speech recognition by NVIDIA Parakeet TDT v3 via FluidAudio.\ngithub.com/neelashkannan/neelSpeak",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private func startIfReady() {
        viewModel.refreshPermissions()
        guard viewModel.microphoneStatus == .authorized else {
            coordinator.markSetupRequired()
            if !viewModel.setupComplete { showMainWindow() }
            return
        }
        guard viewModel.accessibilityTrusted else {
            coordinator.markSetupRequired()
            if !viewModel.setupComplete { showMainWindow() }
            return
        }
        coordinator.prepare(model: viewModel.selectedModel)
    }

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let wasReady = self.viewModel.permissionsGranted
                let wasAccessibilityTrusted = self.viewModel.accessibilityTrusted
                self.viewModel.refreshPermissions()
                if !wasAccessibilityTrusted && self.viewModel.accessibilityTrusted {
                    self.coordinator.restartHotkeyMonitoring()
                }
                if !wasReady && self.viewModel.permissionsGranted && self.viewModel.setupComplete {
                    self.startIfReady()
                }
            }
        }
    }

    /// Standard app, Edit and Window menus. The menu bar only shows while the
    /// window is open, but the Edit menu's key equivalents are what make ⌘C/⌘V
    /// work in NeelSpeak's own text fields — including pasting dictation into them.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About NeelSpeak", action: #selector(showAbout), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide NeelSpeak", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit NeelSpeak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu: appMenu, title: "NeelSpeak")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu: editMenu, title: "Edit")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(submenu: windowMenu, title: "Window")
        NSApp.windowsMenu = windowMenu

        return main
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
