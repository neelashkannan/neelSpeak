import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let viewModel: VoiceTyperViewModel
    private var state: DictationCoordinator.State = .setupRequired

    var onOpenWindow: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRetrySetup: (() -> Void)?
    var onShowAbout: (() -> Void)?

    init(viewModel: VoiceTyperViewModel) {
        self.viewModel = viewModel
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        item.button?.imagePosition = .imageLeading
        update(state: .setupRequired)
    }

    func update(state: DictationCoordinator.State) {
        self.state = state
        guard let button = item.button else { return }

        let glyph: NSImage
        switch state {
        case .recording:
            glyph = MenuBarGlyph.image(tint: .systemRed)
        case .setupRequired, .error:
            glyph = MenuBarGlyph.image(badged: true)
        default:
            glyph = MenuBarGlyph.image()
        }
        button.image = glyph
        button.appearsDisabled = {
            switch state {
            case .warming, .downloadingModel: return true
            default: return false
            }
        }()

        if case .downloadingModel(let progress) = state {
            button.title = " \(Int(progress * 100))%"
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        } else {
            button.title = ""
        }
        button.setAccessibilityLabel("NeelSpeak — \(state.title)")
        button.toolTip = "NeelSpeak — \(statusLine)"
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if let release = viewModel.availableUpdate {
            menu.addItem(action("NeelSpeak \(release.version) is available…", #selector(openUpdate)))
        }
        switch state {
        case .setupRequired, .error:
            menu.addItem(action("Finish Setup…", #selector(retrySetup)))
        default:
            break
        }

        menu.addItem(.separator())
        let copy = action("Copy Last Dictation", #selector(copyLastDictation))
        copy.isEnabled = !viewModel.history.isEmpty
        if let latest = viewModel.history.first {
            copy.toolTip = latest.text
        }
        menu.addItem(copy)

        menu.addItem(.separator())
        menu.addItem(action("Open NeelSpeak", #selector(openWindow)))
        menu.addItem(action("Settings…", #selector(openSettings), key: ","))
        let login = action("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = viewModel.launchAtLoginEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(action("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(action("About NeelSpeak", #selector(showAbout)))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NeelSpeak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private var statusLine: String {
        switch state {
        case .idle:
            return "Ready — hold \(viewModel.hotkeyTrigger.keyCapLabel) to dictate"
        case .downloadingModel(let progress):
            return "Downloading speech model… \(Int(progress * 100))%"
        case .error(let message):
            return "Needs attention: \(message.prefix(60))"
        default:
            return state.title
        }
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openWindow() { onOpenWindow?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func retrySetup() { onRetrySetup?() }
    @objc private func showAbout() { onShowAbout?() }
    @objc private func copyLastDictation() { viewModel.copyLastDictation() }
    @objc private func openUpdate() { viewModel.openUpdatePage() }

    @objc private func toggleLaunchAtLogin() {
        viewModel.setLaunchAtLogin(!viewModel.launchAtLoginEnabled)
        if viewModel.launchAtLoginNeedsApproval { viewModel.openLoginItemsSettings() }
    }

    @objc private func checkForUpdates() {
        viewModel.checkForUpdates(userInitiated: true)
        onOpenSettings?()
    }
}

/// The NeelSpeak waveform drawn as a menu bar glyph: five rounded bars echoing
/// the app icon. Template by default so it follows the menu bar's appearance.
enum MenuBarGlyph {
    static func image(tint: NSColor? = nil, badged: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let heights: [CGFloat] = [5, 10, 15, 10, 5]
            let barWidth: CGFloat = 2.2
            let gap: CGFloat = 1.4
            let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
            var x = (size.width - total) / 2
            (tint ?? .black).setFill()
            for height in heights {
                let rect = NSRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)
                NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
                x += barWidth + gap
            }
            if badged {
                // Punch a ring out around the badge so it reads at 18 pt.
                let badge = NSRect(x: size.width - 6.5, y: size.height - 6.5, width: 6, height: 6)
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: badge.insetBy(dx: -1.2, dy: -1.2)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSBezierPath(ovalIn: badge).fill()
            }
            return true
        }
        image.isTemplate = tint == nil
        return image
    }
}
