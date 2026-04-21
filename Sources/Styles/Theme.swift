import SwiftUI

enum CardKind: Hashable {
    case brutalist
}

struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let background: Color
    let surface: Color
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let hairline: Color
    let accent: Color
    let displayFont: Font
    let sectionLabelFont: Font
    let bodyFont: Font
    let bodyMediumFont: Font
    let captionFont: Font
    let tinyFont: Font
    let monoFont: Font
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let cardKind: CardKind

    var prefersDarkMode: Bool { id == "brutalist-inverse" }

    private static func brutalistFonts() -> (
        display: Font, sectionLabel: Font, body: Font, bodyMed: Font,
        caption: Font, tiny: Font, mono: Font
    ) {
        (
            .system(size: 34, weight: .black, design: .monospaced),
            .system(size: 11, weight: .heavy, design: .monospaced),
            .system(size: 16, weight: .regular, design: .monospaced),
            .system(size: 16, weight: .bold, design: .monospaced),
            .system(size: 12, weight: .regular, design: .monospaced),
            .system(size: 10, weight: .heavy, design: .monospaced),
            .system(size: 48, weight: .bold, design: .monospaced)
        )
    }

    private static func brutalist(
        id: String, name: String,
        background: Color, surface: Color,
        primary: Color, secondary: Color, tertiary: Color,
        hairline: Color, accent: Color
    ) -> Theme {
        let f = brutalistFonts()
        return Theme(
            id: id, name: name,
            background: background, surface: surface,
            primary: primary, secondary: secondary, tertiary: tertiary,
            hairline: hairline, accent: accent,
            displayFont: f.display, sectionLabelFont: f.sectionLabel,
            bodyFont: f.body, bodyMediumFont: f.bodyMed,
            captionFont: f.caption, tinyFont: f.tiny, monoFont: f.mono,
            cornerRadius: 0, borderWidth: 2.5, cardKind: .brutalist
        )
    }

    static let brutalist = brutalist(
        id: "brutalist", name: "Cream",
        background: Color(red: 0.98, green: 0.96, blue: 0.92),
        surface: .white,
        primary: .black, secondary: Color(white: 0.15), tertiary: Color(white: 0.30),
        hairline: .black, accent: Color(red: 1.0, green: 0.30, blue: 0.10)
    )

    static let brutalistStark = brutalist(
        id: "brutalist-stark", name: "Stark White",
        background: .white, surface: .white,
        primary: .black, secondary: Color(white: 0.15), tertiary: Color(white: 0.35),
        hairline: .black, accent: Color(red: 0.90, green: 0.10, blue: 0.10)
    )

    static let brutalistInverse = brutalist(
        id: "brutalist-inverse", name: "Ink",
        background: Color(white: 0.04), surface: Color(white: 0.08),
        primary: .white, secondary: Color(white: 0.80), tertiary: Color(white: 0.55),
        hairline: .white, accent: Color(red: 1.0, green: 0.85, blue: 0.20)
    )

    static let brutalistOrange = brutalist(
        id: "brutalist-orange", name: "Tangerine",
        background: Color(red: 0.99, green: 0.95, blue: 0.88),
        surface: .white,
        primary: .black, secondary: Color(white: 0.15), tertiary: Color(white: 0.30),
        hairline: .black, accent: Color(red: 0.95, green: 0.45, blue: 0.05)
    )

    static let brutalistPink = brutalist(
        id: "brutalist-pink", name: "Blush",
        background: Color(red: 0.99, green: 0.94, blue: 0.94),
        surface: .white,
        primary: .black, secondary: Color(white: 0.15), tertiary: Color(white: 0.30),
        hairline: .black, accent: Color(red: 0.88, green: 0.20, blue: 0.45)
    )

    static let brutalistLime = brutalist(
        id: "brutalist-lime", name: "Lime",
        background: Color(red: 0.97, green: 0.98, blue: 0.90),
        surface: .white,
        primary: .black, secondary: Color(white: 0.15), tertiary: Color(white: 0.30),
        hairline: .black, accent: Color(red: 0.40, green: 0.65, blue: 0.10)
    )

    static let all: [Theme] = [
        .brutalist, .brutalistStark, .brutalistInverse,
        .brutalistOrange, .brutalistPink, .brutalistLime
    ]
}

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()
    private static let storageKey = "theme.id"

    var current: Theme

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.current = Theme.all.first(where: { $0.id == raw }) ?? .brutalist
    }

    func select(_ theme: Theme) {
        current = theme
        UserDefaults.standard.set(theme.id, forKey: Self.storageKey)
    }
}
