#if DEBUG
import AppKit
import SwiftUI

/// Renders each window pane offscreen to PNG for visual review. Debug builds only.
@MainActor
enum UISnapshotRenderer {
    static func run(outputDirectory: URL) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let coordinator = DictationCoordinator()
        let viewModel = VoiceTyperViewModel(coordinator: coordinator, themeStore: OverlayThemeStore(), isSnapshot: true)
        viewModel.update(state: .idle)
        viewModel.record(DictationResult(text: "Can you send the quarterly report to Priya before Friday?", rawText: "um can you send the the quarterly report to Priya before Friday", cleanupIssue: nil, audioDuration: 4.2))
        viewModel.record(DictationResult(text: "Let's meet at four tomorrow at the office.", rawText: nil, cleanupIssue: nil, audioDuration: 2.8))

        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let suffix = appearance == .aqua ? "light" : "dark"
            for step in SetupFlowView.Step.allCases {
                capture(SetupFlowView(viewModel: viewModel, initialStep: step), appearance: appearance,
                        to: outputDirectory.appendingPathComponent("setup-\(step.rawValue)-\(suffix).png"))
            }
            viewModel.finishSetupAndRunInBackground()
            let navigation = DashboardNavigation()
            for section in DashboardSection.allCases {
                navigation.section = section
                let view = VoiceTyperDashboard(viewModel: viewModel, navigation: navigation)
                capture(view, appearance: appearance,
                        to: outputDirectory.appendingPathComponent("main-\(section.rawValue)-\(suffix).png"))
            }
        }
        viewModel.cleanupMode = .conservative
        viewModel.cleanupEngine = .anthropic
        let navigation = DashboardNavigation()
        navigation.section = .cleanup
        capture(VoiceTyperDashboard(viewModel: viewModel, navigation: navigation), appearance: .aqua,
                to: outputDirectory.appendingPathComponent("main-cleanup-on-light.png"))
        viewModel.cleanupEngine = .openAICompatible
        capture(VoiceTyperDashboard(viewModel: viewModel, navigation: navigation), appearance: .darkAqua,
                to: outputDirectory.appendingPathComponent("main-cleanup-openai-dark.png"))
        print("rendered to \(outputDirectory.path)")
    }

    private static func capture<V: View>(_ view: V, appearance: NSAppearance.Name, to url: URL) {
        let size = NSSize(width: 860, height: 620)
        let hosting = NSHostingController(rootView: view.environment(\.colorScheme, appearance == .aqua ? .light : .dark))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.titlebarAppearsTransparent = true
        window.contentViewController = hosting
        window.setContentSize(size)
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        guard let contentView = window.contentView,
              let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else { return }
        contentView.cacheDisplay(in: contentView.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
