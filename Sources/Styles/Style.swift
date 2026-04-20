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
        let theme = ThemeManager.shared.current
        if theme.cardKind == .brutalist {
            Rectangle().fill(theme.hairline).frame(height: 1)
        } else {
            Rectangle().fill(theme.hairline).frame(height: theme.borderWidth > 0 ? 0.5 : 0.5)
        }
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
        switch theme.cardKind {
        case .bauhaus:
            content
                .padding(14)
                .overlay(
                    Rectangle().stroke(theme.hairline, lineWidth: theme.borderWidth)
                )
        case .soft:
            content
                .padding(14)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .shadow(color: theme.accent.opacity(0.12), radius: 8, x: 0, y: 3)
        case .pastelOutline:
            content
                .padding(14)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .strokeBorder(
                            theme.hairline,
                            style: StrokeStyle(lineWidth: theme.borderWidth, dash: [4, 3])
                        )
                )
        case .brutalist:
            content
                .padding(14)
                .background(theme.surface)
                .overlay(
                    Rectangle().stroke(theme.primary, lineWidth: theme.borderWidth)
                )
                .shadow(color: theme.primary, radius: 0, x: 4, y: 4)
        case .glass:
            content
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(theme.hairline, lineWidth: theme.borderWidth)
                )
        }
    }
}

extension View {
    func themedCard() -> some View {
        modifier(ThemedCard(theme: ThemeManager.shared.current))
    }
}

struct ThemedBackground: View {
    var body: some View {
        let theme = ThemeManager.shared.current
        switch theme.cardKind {
        case .glass:
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.92, blue: 1.0),
                    Color(red: 0.95, green: 0.88, blue: 1.0),
                    Color(red: 0.88, green: 0.98, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        default:
            theme.background.ignoresSafeArea()
        }
    }
}
