import SwiftUI

enum CardKind: Hashable {
    case bauhaus      // thin stroke, sharp corners, no fill
    case soft         // filled card, rounded, soft shadow
    case pastelOutline // filled pastel, dashed border
    case brutalist    // thick stroke, offset hard shadow
    case glass        // translucent material
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

    static let bauhaus = Theme(
        id: "bauhaus",
        name: "Bauhaus",
        background: Color(white: 1.0),
        surface: Color(white: 1.0),
        primary: .black,
        secondary: Color(white: 0.35),
        tertiary: Color(white: 0.60),
        hairline: Color(white: 0.88),
        accent: Color(red: 0.78, green: 0.15, blue: 0.15),
        displayFont: .system(size: 28, weight: .bold, design: .default),
        sectionLabelFont: .system(size: 11, weight: .semibold, design: .default),
        bodyFont: .system(size: 16, weight: .regular, design: .default),
        bodyMediumFont: .system(size: 16, weight: .medium, design: .default),
        captionFont: .system(size: 12, weight: .regular, design: .default),
        tinyFont: .system(size: 10, weight: .semibold, design: .default),
        monoFont: .system(size: 48, weight: .light, design: .monospaced),
        cornerRadius: 0,
        borderWidth: 0.5,
        cardKind: .bauhaus
    )

    static let warmOrange = Theme(
        id: "warm",
        name: "Warm Orange",
        background: Color(red: 0.99, green: 0.96, blue: 0.91),
        surface: Color(red: 1.0, green: 0.99, blue: 0.96),
        primary: Color(red: 0.28, green: 0.18, blue: 0.12),
        secondary: Color(red: 0.55, green: 0.40, blue: 0.28),
        tertiary: Color(red: 0.72, green: 0.58, blue: 0.45),
        hairline: Color(red: 0.92, green: 0.82, blue: 0.70),
        accent: Color(red: 0.85, green: 0.45, blue: 0.15),
        displayFont: .system(size: 30, weight: .bold, design: .rounded),
        sectionLabelFont: .system(size: 11, weight: .bold, design: .rounded),
        bodyFont: .system(size: 16, weight: .regular, design: .rounded),
        bodyMediumFont: .system(size: 16, weight: .semibold, design: .rounded),
        captionFont: .system(size: 12, weight: .regular, design: .rounded),
        tinyFont: .system(size: 10, weight: .bold, design: .rounded),
        monoFont: .system(size: 48, weight: .light, design: .rounded),
        cornerRadius: 14,
        borderWidth: 0,
        cardKind: .soft
    )

    static let pastel = Theme(
        id: "pastel",
        name: "Pastel",
        background: Color(red: 0.98, green: 0.97, blue: 0.99),
        surface: Color(red: 1.0, green: 1.0, blue: 1.0),
        primary: Color(red: 0.25, green: 0.22, blue: 0.35),
        secondary: Color(red: 0.50, green: 0.45, blue: 0.60),
        tertiary: Color(red: 0.70, green: 0.65, blue: 0.80),
        hairline: Color(red: 0.85, green: 0.80, blue: 0.92),
        accent: Color(red: 0.95, green: 0.55, blue: 0.70),
        displayFont: .system(size: 28, weight: .semibold, design: .rounded),
        sectionLabelFont: .system(size: 10, weight: .medium, design: .rounded),
        bodyFont: .system(size: 16, weight: .regular, design: .rounded),
        bodyMediumFont: .system(size: 16, weight: .medium, design: .rounded),
        captionFont: .system(size: 12, weight: .regular, design: .rounded),
        tinyFont: .system(size: 10, weight: .medium, design: .rounded),
        monoFont: .system(size: 48, weight: .regular, design: .rounded),
        cornerRadius: 18,
        borderWidth: 1.5,
        cardKind: .pastelOutline
    )

    static let brutalist = Theme(
        id: "brutalist",
        name: "Brutalist",
        background: Color(red: 0.98, green: 0.96, blue: 0.92),
        surface: Color(red: 1.0, green: 1.0, blue: 1.0),
        primary: .black,
        secondary: Color(white: 0.15),
        tertiary: Color(white: 0.30),
        hairline: .black,
        accent: Color(red: 1.0, green: 0.30, blue: 0.10),
        displayFont: .system(size: 34, weight: .black, design: .monospaced),
        sectionLabelFont: .system(size: 11, weight: .heavy, design: .monospaced),
        bodyFont: .system(size: 16, weight: .regular, design: .monospaced),
        bodyMediumFont: .system(size: 16, weight: .bold, design: .monospaced),
        captionFont: .system(size: 12, weight: .regular, design: .monospaced),
        tinyFont: .system(size: 10, weight: .heavy, design: .monospaced),
        monoFont: .system(size: 48, weight: .bold, design: .monospaced),
        cornerRadius: 0,
        borderWidth: 2.5,
        cardKind: .brutalist
    )

    static let glass = Theme(
        id: "glass",
        name: "Glass",
        background: Color(red: 0.92, green: 0.94, blue: 0.99),
        surface: Color.white.opacity(0.55),
        primary: Color(red: 0.15, green: 0.20, blue: 0.35),
        secondary: Color(red: 0.40, green: 0.45, blue: 0.60),
        tertiary: Color(red: 0.60, green: 0.65, blue: 0.78),
        hairline: Color.white.opacity(0.6),
        accent: Color(red: 0.35, green: 0.55, blue: 0.95),
        displayFont: .system(size: 30, weight: .semibold, design: .default),
        sectionLabelFont: .system(size: 11, weight: .medium, design: .default),
        bodyFont: .system(size: 16, weight: .regular, design: .default),
        bodyMediumFont: .system(size: 16, weight: .medium, design: .default),
        captionFont: .system(size: 12, weight: .regular, design: .default),
        tinyFont: .system(size: 10, weight: .medium, design: .default),
        monoFont: .system(size: 48, weight: .light, design: .default),
        cornerRadius: 20,
        borderWidth: 0.5,
        cardKind: .glass
    )

    static let all: [Theme] = [.brutalist]
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
