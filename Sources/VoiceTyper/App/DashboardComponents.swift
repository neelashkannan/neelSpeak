import AppKit
import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case general
    case cleanup
    case appearance
    case history
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .cleanup: return "AI Cleanup"
        case .appearance: return "Appearance"
        case .history: return "History"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .cleanup: return "wand.and.stars"
        case .appearance: return "paintpalette"
        case .history: return "clock.arrow.circlepath"
        case .about: return "info.circle"
        }
    }
}

/// Which pane the main window shows; lets the menu bar deep-link into it.
@MainActor
final class DashboardNavigation: ObservableObject {
    @Published var section: DashboardSection? = .general
}

struct AppIconMark: View {
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

/// A keyboard key, e.g. "Right ⌥".
struct KeyCap: View {
    let label: String
    var large = false

    var body: some View {
        Text(label)
            .font(.system(size: large ? 15 : 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, large ? 12 : 7)
            .padding(.vertical, large ? 6 : 3)
            .background(
                RoundedRectangle(cornerRadius: large ? 7 : 5, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: large ? 7 : 5, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.28), lineWidth: 0.5)
            )
            .accessibilityLabel(label.replacingOccurrences(of: "⌥", with: "Option"))
    }
}

struct StateBadge: View {
    let state: DictationCoordinator.State

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.accentColor)
                .frame(width: 7, height: 7)
            Text(state.title)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(state.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(state.accentColor.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// One permission with its status and a button to fix it.
struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(granted ? Color.green : Color.orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17))
                    .foregroundStyle(.green)
                    .accessibilityLabel("\(title) allowed")
            } else {
                Button(actionTitle, action: action)
            }
        }
    }
}

/// Small static capsule showing a pill theme.
struct PillSwatch: View {
    let theme: OverlayTheme
    var width: CGFloat = 54
    var height: CGFloat = 24

    var body: some View {
        Capsule()
            .fill(theme.fill)
            .overlay(
                Capsule().strokeBorder(
                    AngularGradient(
                        colors: theme.borderColors + [theme.borderColors.first ?? .white],
                        center: .center
                    ),
                    lineWidth: 2
                )
            )
            .overlay(
                HStack(spacing: 2.5) {
                    ForEach([0.35, 0.7, 1.0, 0.7, 0.35], id: \.self) { scale in
                        Capsule()
                            .fill(theme.borderColors[0])
                            .frame(width: 2.5, height: height * 0.5 * scale)
                    }
                }
            )
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

/// Grey explanatory text under a form row.
struct FootnoteText: View {
    let text: String
    let alignment: TextAlignment

    init(_ text: String, alignment: TextAlignment = .leading) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

/// Orange inline warning used for setup problems and cleanup errors.
struct IssueLabel: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.system(size: 12))
        .foregroundStyle(.orange)
    }
}

extension DictationCoordinator.State {
    var accentColor: Color {
        switch self {
        case .setupRequired, .error:
            return .orange
        case .downloadingModel, .warming:
            return .blue
        case .idle:
            return .green
        case .recording:
            return .red
        case .transcribing:
            return .indigo
        case .cleaning:
            return .purple
        }
    }
}
