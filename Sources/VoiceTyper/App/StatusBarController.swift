import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
    private let openMenuItem = NSMenuItem(title: "Open NeelSpeak", action: #selector(openVoiceTyper), keyEquivalent: "")
    private let retryMenuItem = NSMenuItem(title: "Retry Setup", action: #selector(retrySetup), keyEquivalent: "r")

    var onOpenWindow: (() -> Void)?
    var onRetrySetup: (() -> Void)?

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureMenu()
        update(state: .warming)
    }

    private func configureMenu() {
        openMenuItem.target = self
        menu.addItem(openMenuItem)
        menu.addItem(NSMenuItem.separator())

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        let hotkeyHint = NSMenuItem(title: "Hold Option to dictate", action: nil, keyEquivalent: "")
        hotkeyHint.isEnabled = false
        menu.addItem(hotkeyHint)

        retryMenuItem.target = self
        menu.addItem(retryMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit NeelSpeak",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu
    }

    func update(state: DictationCoordinator.State) {
        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.title)
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.title = " NeelSpeak"

        switch state {
        case .setupRequired:
            statusMenuItem.title = "Setup required"
        case .downloadingModel(let progress):
            statusMenuItem.title = "Downloading model \(Int(progress * 100))%"
        case .warming:
            statusMenuItem.title = "Loading model…"
        case .idle:
            statusMenuItem.title = "Ready"
        case .recording:
            statusMenuItem.title = "Listening…"
        case .transcribing:
            statusMenuItem.title = "Transcribing…"
        case .cleaning:
            statusMenuItem.title = "Cleaning up…"
        case .error(let msg):
            statusMenuItem.title = "Error: \(msg.prefix(60))"
        }
    }

    @objc private func openVoiceTyper() {
        onOpenWindow?()
    }

    @objc private func retrySetup() {
        onRetrySetup?()
    }
}
