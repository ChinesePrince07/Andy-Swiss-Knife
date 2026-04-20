import SwiftUI

enum AppColors {
    static let background = Color(white: 1.0)
    static let surface = Color(white: 1.0)
    static let primary = Color.black
    static let secondary = Color(white: 0.35)
    static let tertiary = Color(white: 0.60)
    static let hairline = Color(white: 0.88)
    static let accent = Color(red: 0.78, green: 0.15, blue: 0.15)
}

enum AppType {
    static let displayTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let sectionLabel = Font.system(size: 11, weight: .semibold, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 16, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let tiny = Font.system(size: 10, weight: .semibold, design: .default)
    static let mono = Font.system(size: 48, weight: .light, design: .monospaced)
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.hairline)
            .frame(height: 0.5)
    }
}

struct BauhausCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(AppColors.hairline, lineWidth: 0.5)
            )
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
