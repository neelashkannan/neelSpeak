import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    let navigation = DashboardNavigation()

    init(viewModel: VoiceTyperViewModel) {
        let rootView = VoiceTyperDashboard(viewModel: viewModel, navigation: navigation)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "NeelSpeak"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 760, height: 540)
        window.setContentSize(NSSize(width: 860, height: 620))
        window.setFrameAutosaveName("NeelSpeakMainWindow")
        window.isReleasedWhenClosed = false
        if !window.setFrameUsingName("NeelSpeakMainWindow") {
            window.center()
        }

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(section: DashboardSection? = nil) {
        guard let window else { return }
        if let section { navigation.section = section }
        // Behave like a regular app (Dock icon, ⌘-Tab, menu bar) while the
        // window is open; go back to menu-bar-only when it closes.
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}
