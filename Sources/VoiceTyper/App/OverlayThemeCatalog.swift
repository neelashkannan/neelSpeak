import SwiftUI

struct OverlayTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let fill: Color           // inside colour of the capsule
    let borderColors: [Color] // border palette — all shades of ONE hue, distinct from fill

    static func == (lhs: OverlayTheme, rhs: OverlayTheme) -> Bool { lhs.id == rhs.id }
}

// Each theme is a strict two-colour combo: one fill colour for the inside,
// one border hue (expressed as 2–3 shades so the rotating angular gradient
// still visibly travels) that is intentionally far from the fill on the
// colour wheel. Fills are kept dark enough that the white "Transcribing…"
// label stays legible.
enum OverlayThemeCatalog {
    static let all: [OverlayTheme] = [
        OverlayTheme(
            id: "midnight-pink",
            name: "Midnight · Pink",
            fill: Color(red: 0.04, green: 0.04, blue: 0.06),
            borderColors: [
                Color(red: 1.00, green: 0.20, blue: 0.65),
                Color(red: 1.00, green: 0.45, blue: 0.80)
            ]
        ),
        OverlayTheme(
            id: "midnight-cyan",
            name: "Midnight · Cyan",
            fill: Color(red: 0.04, green: 0.04, blue: 0.06),
            borderColors: [
                Color(red: 0.10, green: 0.90, blue: 1.00),
                Color(red: 0.45, green: 1.00, blue: 0.95)
            ]
        ),
        OverlayTheme(
            id: "midnight-lime",
            name: "Midnight · Lime",
            fill: Color(red: 0.04, green: 0.04, blue: 0.06),
            borderColors: [
                Color(red: 0.65, green: 1.00, blue: 0.20),
                Color(red: 0.85, green: 1.00, blue: 0.45)
            ]
        ),
        OverlayTheme(
            id: "midnight-amber",
            name: "Midnight · Amber",
            fill: Color(red: 0.04, green: 0.04, blue: 0.06),
            borderColors: [
                Color(red: 1.00, green: 0.75, blue: 0.10),
                Color(red: 1.00, green: 0.55, blue: 0.05)
            ]
        ),
        OverlayTheme(
            id: "navy-coral",
            name: "Navy · Coral",
            fill: Color(red: 0.05, green: 0.08, blue: 0.22),
            borderColors: [
                Color(red: 1.00, green: 0.45, blue: 0.40),
                Color(red: 1.00, green: 0.65, blue: 0.55)
            ]
        ),
        OverlayTheme(
            id: "wine-mint",
            name: "Wine · Mint",
            fill: Color(red: 0.18, green: 0.04, blue: 0.10),
            borderColors: [
                Color(red: 0.40, green: 1.00, blue: 0.75),
                Color(red: 0.65, green: 1.00, blue: 0.85)
            ]
        ),
        OverlayTheme(
            id: "forest-magenta",
            name: "Forest · Magenta",
            fill: Color(red: 0.04, green: 0.14, blue: 0.07),
            borderColors: [
                Color(red: 1.00, green: 0.30, blue: 0.85),
                Color(red: 0.95, green: 0.55, blue: 1.00)
            ]
        ),
        OverlayTheme(
            id: "indigo-yellow",
            name: "Indigo · Yellow",
            fill: Color(red: 0.10, green: 0.06, blue: 0.30),
            borderColors: [
                Color(red: 1.00, green: 0.95, blue: 0.20),
                Color(red: 1.00, green: 0.85, blue: 0.45)
            ]
        ),
        OverlayTheme(
            id: "plum-lime",
            name: "Plum · Lime",
            fill: Color(red: 0.18, green: 0.05, blue: 0.20),
            borderColors: [
                Color(red: 0.70, green: 1.00, blue: 0.20),
                Color(red: 0.85, green: 1.00, blue: 0.50)
            ]
        ),
        OverlayTheme(
            id: "teal-pink",
            name: "Teal · Hot Pink",
            fill: Color(red: 0.04, green: 0.18, blue: 0.20),
            borderColors: [
                Color(red: 1.00, green: 0.20, blue: 0.55),
                Color(red: 1.00, green: 0.45, blue: 0.75)
            ]
        ),
        OverlayTheme(
            id: "burgundy-cyan",
            name: "Burgundy · Cyan",
            fill: Color(red: 0.22, green: 0.03, blue: 0.08),
            borderColors: [
                Color(red: 0.20, green: 0.95, blue: 1.00),
                Color(red: 0.55, green: 1.00, blue: 1.00)
            ]
        ),
        OverlayTheme(
            id: "eggplant-mint",
            name: "Eggplant · Mint",
            fill: Color(red: 0.14, green: 0.05, blue: 0.18),
            borderColors: [
                Color(red: 0.30, green: 1.00, blue: 0.70),
                Color(red: 0.55, green: 1.00, blue: 0.80)
            ]
        ),
        OverlayTheme(
            id: "olive-sky",
            name: "Olive · Sky",
            fill: Color(red: 0.14, green: 0.16, blue: 0.04),
            borderColors: [
                Color(red: 0.35, green: 0.75, blue: 1.00),
                Color(red: 0.55, green: 0.90, blue: 1.00)
            ]
        ),
        OverlayTheme(
            id: "crimson-aqua",
            name: "Crimson · Aqua",
            fill: Color(red: 0.28, green: 0.05, blue: 0.10),
            borderColors: [
                Color(red: 0.30, green: 1.00, blue: 0.95),
                Color(red: 0.55, green: 1.00, blue: 0.95)
            ]
        ),
        OverlayTheme(
            id: "slate-orange",
            name: "Slate · Orange",
            fill: Color(red: 0.10, green: 0.12, blue: 0.16),
            borderColors: [
                Color(red: 1.00, green: 0.50, blue: 0.10),
                Color(red: 1.00, green: 0.70, blue: 0.30)
            ]
        ),
        OverlayTheme(
            id: "charcoal-violet",
            name: "Charcoal · Violet",
            fill: Color(red: 0.10, green: 0.10, blue: 0.12),
            borderColors: [
                Color(red: 0.65, green: 0.25, blue: 1.00),
                Color(red: 0.85, green: 0.50, blue: 1.00)
            ]
        ),
        OverlayTheme(
            id: "ink-peach",
            name: "Ink · Peach",
            fill: Color(red: 0.05, green: 0.07, blue: 0.12),
            borderColors: [
                Color(red: 1.00, green: 0.70, blue: 0.55),
                Color(red: 1.00, green: 0.85, blue: 0.70)
            ]
        ),
        OverlayTheme(
            id: "deep-green-pink",
            name: "Pine · Pink",
            fill: Color(red: 0.04, green: 0.10, blue: 0.10),
            borderColors: [
                Color(red: 1.00, green: 0.40, blue: 0.65),
                Color(red: 1.00, green: 0.65, blue: 0.80)
            ]
        )
    ]

    static let defaultID = "midnight-pink"

    static func theme(id: String) -> OverlayTheme {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

@MainActor
final class OverlayThemeStore: ObservableObject {
    private static let storageKey = "overlayThemeID"

    @Published var selectedID: String {
        didSet {
            UserDefaults.standard.set(selectedID, forKey: Self.storageKey)
        }
    }

    var theme: OverlayTheme { OverlayThemeCatalog.theme(id: selectedID) }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        selectedID = stored ?? OverlayThemeCatalog.defaultID
    }
}
