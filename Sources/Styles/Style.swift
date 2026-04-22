import SwiftUI

@MainActor
enum AppColors {
    static var background: Color { ThemeManager.shared.current.background }
    static var surface: Color { ThemeManager.shared.current.surface }
    static var primary: Color { ThemeManager.shared.current.primary }
    static var secondary: Color { ThemeManager.shared.current.secondary }
    static var tertiary: Color { ThemeManager.shared.current.tertiary }
    static var hairline: Color { ThemeManager.shared.current.hairline }
    static var accent: Color { ThemeManager.shared.current.accent }
}

@MainActor
enum AppType {
    static var displayTitle: Font { ThemeManager.shared.current.displayFont }
    static var sectionLabel: Font { ThemeManager.shared.current.sectionLabelFont }
    static var body: Font { ThemeManager.shared.current.bodyFont }
    static var bodyMedium: Font { ThemeManager.shared.current.bodyMediumFont }
    static var caption: Font { ThemeManager.shared.current.captionFont }
    static var tiny: Font { ThemeManager.shared.current.tinyFont }
    static var mono: Font { ThemeManager.shared.current.monoFont }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle().fill(ThemeManager.shared.current.hairline).frame(height: 1)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(AppType.sectionLabel)
            .kerning(1.2)
            .foregroundStyle(AppColors.tertiary)
    }
}

struct ThemedCard: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(theme.surface)
            .overlay(
                Rectangle()
                    .strokeBorder(theme.primary, lineWidth: theme.borderWidth)
            )
    }
}

extension View {
    func themedCard() -> some View {
        modifier(ThemedCard(theme: ThemeManager.shared.current))
    }
}

struct ThemedBackground: View {
    var body: some View {
        ThemeManager.shared.current.background.ignoresSafeArea()
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}
#endif
