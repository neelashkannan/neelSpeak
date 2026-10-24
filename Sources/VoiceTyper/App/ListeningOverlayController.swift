import AppKit
import SwiftUI

// MARK: - View Model

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var mode: ListeningOverlayView.Mode = .listening
    @Published var startedAt: Date = Date()
    /// Smoothed microphone level, 0…1.
    @Published var level: Double = 0
    let themeStore: OverlayThemeStore

    init(themeStore: OverlayThemeStore) {
        self.themeStore = themeStore
    }

    func ingest(level newLevel: Float) {
        let target = Double(newLevel)
        // Rise quickly with the voice, fall back gently between words.
        let factor = target > level ? 0.55 : 0.18
        level += (target - level) * factor
    }
}

// MARK: - Controller

@MainActor
final class ListeningOverlayController {
    private let panel: NSPanel
    private let viewModel: OverlayViewModel
    private var currentState: DictationCoordinator.State = .setupRequired
    private var pendingReveal: DispatchWorkItem?
    private var pendingHide: DispatchWorkItem?

    // Panel is larger than the visual pill so shaped shadows have
    // room to bleed without being clipped by the window edge.
    private static let panelSize = NSSize(width: 420, height: 96)
    /// Delay before the pill appears for a new recording, so a hold that
    /// immediately becomes an Option shortcut never flashes it.
    private static let revealDelay: TimeInterval = 0.12
    private static let noticeDuration: TimeInterval = 1.8

    init(themeStore: OverlayThemeStore) {
        viewModel = OverlayViewModel(themeStore: themeStore)

        let hosting = NSHostingController(rootView: ListeningOverlayView(viewModel: viewModel))

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // hasShadow = false: system shadow traces the rectangular window frame,
        // not the capsule shape. All shadows are drawn in SwiftUI on the Capsule.
        panel.hasShadow = false
        // .statusBar (level 25) sits above ordinary floating windows and most
        // fullscreen content, so the pill is reliably on top of whatever app
        // the user is dictating into.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.isMovable = false
        // Mouse events pass through the transparent areas of the panel.
        panel.ignoresMouseEvents = true
        panel.setAccessibilityElement(false)

        positionPanel()
        panel.orderFrontRegardless()
    }

    func update(state: DictationCoordinator.State) {
        currentState = state

        switch state {
        case .recording:
            viewModel.level = 0
            viewModel.startedAt = Date()
            scheduleReveal()
        case .transcribing:
            cancelPendingReveal()
            show(mode: .transcribing)
        case .cleaning:
            show(mode: .cleaning)
        default:
            cancelPendingReveal()
            // Let a notice raised alongside this state change finish showing.
            if case .notice = viewModel.mode, viewModel.isVisible { return }
            hide()
        }
    }

    func update(level: Float) {
        guard case .recording = currentState else { return }
        viewModel.ingest(level: level)
    }

    func show(notice: DictationCoordinator.Notice) {
        cancelPendingReveal()
        show(mode: .notice(notice))
        let hide = DispatchWorkItem { [weak self] in
            guard let self, case .notice = self.viewModel.mode else { return }
            self.hide()
        }
        pendingHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.noticeDuration, execute: hide)
    }

    private func scheduleReveal() {
        cancelPendingReveal()
        let reveal = DispatchWorkItem { [weak self] in
            guard let self, case .recording = self.currentState else { return }
            self.show(mode: .listening)
        }
        pendingReveal = reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealDelay, execute: reveal)
    }

    private func cancelPendingReveal() {
        pendingReveal?.cancel()
        pendingReveal = nil
    }

    private func show(mode: ListeningOverlayView.Mode) {
        pendingHide?.cancel()
        pendingHide = nil
        if !viewModel.isVisible { positionPanel() }
        panel.orderFrontRegardless()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
            viewModel.mode = mode
            viewModel.isVisible = true
        }
    }

    private func hide() {
        pendingHide?.cancel()
        pendingHide = nil
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            viewModel.isVisible = false
        }
    }

    private func positionPanel() {
        // Prefer the screen containing the mouse so the pill follows the user
        // across displays; fall back to the key/main screen.
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Root View
//
// The panel stays on-screen permanently. When isVisible = false the ZStack
// renders nothing (fully transparent). SwiftUI transition animates the pill.

struct ListeningOverlayView: View {
    enum Mode: Equatable {
        case listening
        case transcribing
        case cleaning
        case notice(DictationCoordinator.Notice)
    }

    @ObservedObject var viewModel: OverlayViewModel
    @ObservedObject private var themeStore: OverlayThemeStore

    init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
        self._themeStore = ObservedObject(wrappedValue: viewModel.themeStore)
    }

    var body: some View {
        ZStack {
            if viewModel.isVisible {
                PillView(viewModel: viewModel, theme: themeStore.theme)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: -14)
                                .combined(with: .scale(scale: 0.82, anchor: .top))
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.88, anchor: .top)
                                .combined(with: .opacity)
                        )
                    )
            }
        }
        .frame(width: 420, height: 96)
        .clipped()
    }
}

// MARK: - Pill

private struct PillView: View {
    @ObservedObject var viewModel: OverlayViewModel
    let theme: OverlayTheme

    private let pillW: CGFloat = 340
    private let pillH: CGFloat = 56

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                PillBackground(mode: viewModel.mode, theme: theme, tick: tl.date.timeIntervalSinceReferenceDate)
                    .frame(width: pillW, height: pillH)
            }

            Group {
                switch viewModel.mode {
                case .listening:
                    TimelineView(.animation) { tl in
                        ListeningContent(
                            startedAt: viewModel.startedAt,
                            level: viewModel.level,
                            accent: theme.borderColors[0],
                            tick: tl.date.timeIntervalSinceReferenceDate
                        )
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
                case .transcribing:
                    StatusContent(accent: accent, symbol: nil, title: "Transcribing…")
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                case .cleaning:
                    StatusContent(accent: accent, symbol: "wand.and.stars", title: "Cleaning up…")
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                case .notice(let notice):
                    NoticeContent(notice: notice, accent: accent)
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: viewModel.mode)
            .frame(width: pillW, height: pillH)
        }
        .accessibilityHidden(true)
    }

    private var accent: Color {
        theme.borderColors[min(2, theme.borderColors.count - 1)]
    }
}

// MARK: - Listening Content

private struct ListeningContent: View {
    let startedAt: Date
    let level: Double
    let accent: Color
    let tick: TimeInterval

    var body: some View {
        let elapsed = tick - startedAt.timeIntervalSinceReferenceDate
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }

            CompactWaveform(tick: tick, level: level, color: accent)
                .frame(width: 120, height: 24)

            Spacer(minLength: 0)

            Text(formattedElapsed(elapsed))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(accent.opacity(0.85))
        }
        .padding(.horizontal, 18)
    }

    private func formattedElapsed(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed.rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Working / Notice Content

private struct StatusContent: View {
    let accent: Color
    let symbol: String?
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .symbolEffect(.pulse, options: .repeating)
                    .frame(width: 22, height: 22)
            } else {
                PulsingRing(color: accent)
                    .frame(width: 22, height: 22)
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
        }
    }
}

private struct NoticeContent: View {
    let notice: DictationCoordinator.Notice
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
    }

    private var symbol: String {
        switch notice {
        case .noSpeech: return "waveform.slash"
        case .notReady: return "hourglass"
        case .microphoneUnavailable: return "mic.slash.fill"
        case .cleanupSkipped: return "exclamationmark.triangle.fill"
        }
    }

    private var title: String {
        switch notice {
        case .noSpeech: return "No speech detected"
        case .notReady(let reason): return reason
        case .microphoneUnavailable: return "Microphone unavailable"
        case .cleanupSkipped: return "Pasted without cleanup"
        }
    }
}

// MARK: - Pill Background

private struct PillBackground: View {
    let mode: ListeningOverlayView.Mode
    let theme: OverlayTheme
    let tick: TimeInterval

    // Close the angular gradient by repeating the first stop.
    private var stops: [Color] { theme.borderColors + [theme.borderColors.first ?? .white] }

    private var rotation: Angle { .degrees(tick * 80) }

    private var neonGradient: AngularGradient {
        AngularGradient(colors: stops, center: .center, angle: rotation)
    }

    var body: some View {
        ZStack {
            // Solid theme fill — no soft drop-shadow, so nothing bleeds into
            // a rectangular halo around the pill.
            Capsule()
                .fill(theme.fill)

            // Subtle top sheen for depth.
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.55)
                    )
                )

            // Wide, blurred outer halo of the same rotating gradient — gives
            // the neon "glow" feel without producing a square shadow box.
            Capsule()
                .stroke(neonGradient, lineWidth: 6)
                .blur(radius: 7)
                .opacity(0.55)

            // Crisp neon border that rotates around the capsule.
            Capsule()
                .strokeBorder(neonGradient, lineWidth: 1.6)
        }
    }
}

// MARK: - Waveform

private struct CompactWaveform: View {
    let tick: TimeInterval
    let level: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let bars = 22
            let centerY = size.height / 2
            let step = size.width / CGFloat(bars - 1)
            for index in 0..<bars {
                let normalized = Double(index) / Double(bars - 1)
                let distanceFromCenter = abs(normalized - 0.5) * 2
                let envelope = pow(1 - distanceFromCenter, 1.4)
                let motion = (sin(tick * 8.3 + Double(index) * 0.68) + 1) / 2
                let secondary = (sin(tick * 3.1 - Double(index) * 0.25) + 1) / 2
                let maxBarHeight = size.height * 0.9
                // Bars idle as a low ripple and grow with the live input level.
                let energy = 0.12 + 0.88 * level
                let height = 2 + maxBarHeight * envelope * energy * (0.45 + 0.55 * motion) + secondary * 1.5 * envelope
                let x = CGFloat(index) * step
                var path = Path()
                path.move(to: CGPoint(x: x, y: centerY - CGFloat(height / 2)))
                path.addLine(to: CGPoint(x: x, y: centerY + CGFloat(height / 2)))
                context.stroke(
                    path,
                    with: .color(color.opacity(0.30 + envelope * 0.60 + motion * 0.12)),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                )
            }
        }
    }
}

// MARK: - Pulsing Ring

private struct PulsingRing: View {
    let color: Color
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 1

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(opacity * 0.5), lineWidth: 1.5)
                .scaleEffect(scale)
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 10, height: 10)
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                scale = 1.6
                opacity = 0
            }
        }
    }
}
