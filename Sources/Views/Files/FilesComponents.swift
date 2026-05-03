import SwiftUI

// MARK: - Subject folder metadata

private func subjectIcon(for name: String) -> String {
    let l = name.lowercased()
    if l.contains("math") || l.contains("calculus") || l.contains("algebra") || l.contains("geometry") || l.contains("statistics") || l.contains("stats") { return "function" }
    if l.contains("english") || l.contains("literature") || l.contains("writing") || l.contains("essay") || l.contains("composition") { return "book.closed" }
    if l.contains("history") || l.contains("social") || l.contains("gov") || l.contains("politics") { return "clock.arrow.circlepath" }
    if l.contains("science") || l.contains("biology") || l.contains("chemistry") || l.contains("physics") || l.contains("bio") || l.contains("chem") || l.contains("ap ") { return "atom" }
    if l.contains("art") || l.contains("studio") || l.contains("design") { return "paintpalette" }
    if l.contains("music") || l.contains("band") || l.contains("chorus") || l.contains("orchestra") { return "music.note" }
    if l.contains("sport") || l.contains("pe") || l.contains("athletic") || l.contains("gym") { return "figure.run" }
    if l.contains("french") || l.contains("spanish") || l.contains("latin") || l.contains("language") || l.contains("mandarin") || l.contains("chinese") { return "character.bubble" }
    if l.contains("computer") || l.contains(" cs") || l.contains("coding") || l.contains("programming") { return "laptopcomputer" }
    if l.contains("photo") { return "camera" }
    if l.contains("economics") || l.contains("econ") { return "chart.bar" }
    if l.contains("psychology") || l.contains("psych") { return "brain" }
    return "folder"
}

private func subjectColor(for name: String) -> Color {
    let l = name.lowercased()
    if l.contains("math") || l.contains("calculus") || l.contains("algebra") || l.contains("statistics") { return .blue }
    if l.contains("english") || l.contains("literature") || l.contains("writing") { return .red }
    if l.contains("history") || l.contains("social") { return Color(red: 0.6, green: 0.4, blue: 0.2) }
    if l.contains("science") || l.contains("biology") || l.contains("chem") || l.contains("physics") { return .green }
    if l.contains("art") || l.contains("studio") { return .orange }
    if l.contains("music") { return .purple }
    if l.contains("french") || l.contains("spanish") || l.contains("latin") { return Color(red: 0.8, green: 0.5, blue: 0.1) }
    if l.contains("computer") || l.contains(" cs") { return Color(red: 0.2, green: 0.6, blue: 0.8) }
    return Color.primary
}

// MARK: - File Type Glyph

struct DriveFileGlyph: View {
    let item: DriveItem
    let size: CGFloat

    private var typeColor: Color {
        if item.isDirectory { return subjectColor(for: item.name) }
        switch item.fileType {
        case .pdf:   return Color.red
        case .doc:   return Color.blue
        case .xls:   return Color.green
        case .ppt:   return Color.orange
        case .image: return Color.purple
        case .text:  return AppColors.secondary
        default:     return AppColors.tertiary
        }
    }

    private var sfIcon: String {
        if item.isDirectory { return subjectIcon(for: item.name) }
        switch item.fileType {
        case .pdf:    return "doc.richtext.fill"
        case .doc:    return "doc.text.fill"
        case .xls:    return "tablecells.fill"
        case .ppt:    return "rectangle.fill.on.rectangle.fill"
        case .image:  return "photo.fill"
        case .text:   return "doc.plaintext"
        case .folder: return "folder.fill"
        case .other:  return "doc.fill"
        }
    }

    var body: some View {
        _ = ThemeManager.shared.current
        if item.isDirectory {
            return AnyView(folderGlyph)
        } else {
            return AnyView(fileGlyph)
        }
    }

    private var folderGlyph: some View {
        let icon = subjectIcon(for: item.name)
        let color = typeColor
        return ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(color)
                    .frame(width: size * 0.5, height: size * 0.13)
                Rectangle()
                    .fill(color)
                    .frame(width: size, height: size * 0.7)
            }
            Image(systemName: icon)
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.9))
                .offset(y: size * 0.08)
        }
        .frame(width: size, height: size)
    }

    private var fileGlyph: some View {
        Image(systemName: sfIcon)
            .font(.system(size: size * 0.7, weight: .medium))
            .foregroundStyle(typeColor)
            .frame(width: size, height: size)
    }
}

// MARK: - File Row

struct DriveFileRow: View {
    let item: DriveItem
    let isSelected: Bool
    let isDownloading: Bool
    let onTap: () -> Void
    let onMore: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        let starred = UserDefaults.standard.isStarred(path: item.id)
        return Button(action: onTap) {
            HStack(spacing: 12) {
                DriveFileGlyph(item: item, size: 38)
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(AppType.bodyMedium)
                            .foregroundStyle(AppColors.primary)
                            .lineLimit(1)
                        if starred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                    Text(subtitle)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isDownloading {
                    ProgressView()
                        .tint(AppColors.primary)
                        .frame(width: 32, height: 32)
                } else if isSelected {
                    Image(systemName: "checkmark.square.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                } else {
                    Button(action: onMore) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppColors.primary.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !item.isDirectory { parts.append(formatSize(item.size)) }
        if let date = item.modified {
            let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .none
            parts.append(f.string(from: date))
        }
        return parts.joined(separator: " · ")
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

// MARK: - Search Bar

struct DriveSearchBar: View {
    @Binding var text: String
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.tertiary)
            TextField("Search files...", text: $text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.surface)
        .overlay(Rectangle().strokeBorder(AppColors.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppColors.background)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }
}

// MARK: - Breadcrumb Bar

struct BreadcrumbBar: View {
    let segments: [String]
    let onTap: (Int) -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                crumb(name: "ROOT", index: 0)
                ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                    Text(" / ")
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.tertiary)
                    crumb(name: seg.uppercased(), index: idx + 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppColors.surface)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    @ViewBuilder
    private func crumb(name: String, index: Int) -> some View {
        let isLast = index == segments.count
        Button { onTap(index) } label: {
            Text(name)
                .font(.system(size: 11, weight: isLast ? .heavy : .regular, design: .monospaced))
                .kerning(0.8)
                .foregroundStyle(isLast ? AppColors.primary : AppColors.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isLast)
    }
}
