import AppKit
import SwiftUI

// MARK: - View Model

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var mode: ListeningOverlayView.Mode = .listening
    @Published var startedAt: Date = Date()
    let themeStore: OverlayThemeStore

    init(themeStore: OverlayThemeStore) {
        self.themeStore = themeStore
    }
}

// MARK: - Controller

@MainActor
final class ListeningOverlayController {
    private let panel: NSPanel
    private let viewModel: OverlayViewModel
    private var currentState: DictationCoordinator.State = .setupRequired
    private var hotkeyPreviewActive = false

    // Panel is larger than the visual pill so shaped shadows have
    // room to bleed without being clipped by the window edge.
    private static let panelSize = NSSize(width: 420, height: 96)

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

        positionPanel()
        panel.orderFrontRegardless()
    }

    func update(state: DictationCoordinator.State) {
        currentState = state

        switch state {
        case .recording:
            hotkeyPreviewActive = true
            if !viewModel.isVisible { viewModel.startedAt = Date() }
            show(mode: .listening)
        case .transcribing, .cleaning:
            hotkeyPreviewActive = false
            show(mode: .transcribing)
        default:
            if hotkeyPreviewActive {
                show(mode: .listening)
            } else {
                hide()
            }
        }
    }

    func update(hotkeyEvent: HotkeyManager.Event) {
        switch hotkeyEvent {
        case .pressed:
            hotkeyPreviewActive = true
            if !viewModel.isVisible { viewModel.startedAt = Date() }
            show(mode: .listening)
        case .released:
            hotkeyPreviewActive = false
            if currentStateKeepsOverlayVisible { return }
            hide()
        }
    }

    private func show(mode: ListeningOverlayView.Mode) {
        positionPanel()
        panel.orderFrontRegardless()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
            viewModel.mode = mode
            viewModel.isVisible = true
        }
    }

    private func hide() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            viewModel.isVisible = false
        }
    }

    private var currentStateKeepsOverlayVisible: Bool {
        switch currentState {
        case .recording, .transcribing, .cleaning:
            return true
        default:
            return false
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
                TimelineView(.animation) { tl in
                    ListeningContent(startedAt: viewModel.startedAt, accent: theme.borderColors[0], tick: tl.date.timeIntervalSinceReferenceDate)
                }
                .opacity(viewModel.mode == .listening ? 1 : 0)
                .scaleEffect(viewModel.mode == .listening ? 1 : 0.88)

                TranscribingContent(accent: theme.borderColors[min(2, theme.borderColors.count - 1)])
                    .opacity(viewModel.mode == .transcribing ? 1 : 0)
                    .scaleEffect(viewModel.mode == .transcribing ? 1 : 0.88)
            }
            .animation(.easeInOut(duration: 0.22), value: viewModel.mode)
            .frame(width: pillW, height: pillH)
        }
    }
}

// MARK: - Listening Content

private struct ListeningContent: View {
    let startedAt: Date
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

            CompactWaveform(tick: tick, color: accent)
                .frame(width: 90, height: 20)

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

// MARK: - Transcribing Content

private struct TranscribingContent: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            PulsingRing(color: accent)
                .frame(width: 22, height: 22)
            Text("Transcribing…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
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
    let color: Color

    var body: some View {
        Canvas { context, size in
            let bars = 18
            let centerY = size.height / 2
            let step = size.width / CGFloat(bars - 1)
            for index in 0..<bars {
                let normalized = Double(index) / Double(bars - 1)
                let distanceFromCenter = abs(normalized - 0.5) * 2
                let envelope = pow(1 - distanceFromCenter, 1.4)
                let motion = (sin(tick * 8.3 + Double(index) * 0.68) + 1) / 2
                let secondary = (sin(tick * 3.1 - Double(index) * 0.25) + 1) / 2
                let maxBarHeight = size.height * 0.82
                let height = 2 + maxBarHeight * envelope * (0.35 + 0.65 * motion) + secondary * 2 * envelope
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
