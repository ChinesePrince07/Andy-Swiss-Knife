import SwiftUI
import Observation

// MARK: - Aspect-ratio cache

@Observable
@MainActor
final class PhotoRatioCache {
    static let shared = PhotoRatioCache()

    /// width / height. Default 1.0 (square) while loading.
    private(set) var ratios: [String: CGFloat] = [:]

    private let defaultsKey = "photos.ratioCache.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let cached = try? JSONDecoder().decode([String: CGFloat].self, from: data) {
            self.ratios = cached
        }
    }

    func ratio(for key: String) -> CGFloat { ratios[key] ?? 1.0 }

    func set(_ ratio: CGFloat, for key: String) {
        guard ratio > 0.05 && ratio < 20 else { return }
        let existing = ratios[key]
        if let existing, abs(existing - ratio) < 0.005 { return }
        ratios[key] = ratio
        if let data = try? JSONEncoder().encode(ratios) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - Masonry layout

/// Column-based masonry, afilmory-style. Photos placed into the currently
/// shortest column so varied aspect ratios interlock without gaps.
struct PhotoMasonry<Cell: View>: View {
    let photos: [R2Photo]
    let containerWidth: CGFloat
    var columns: Int = 2
    var spacing: CGFloat = 2
    var horizontalPadding: CGFloat = 2
    @ViewBuilder let cell: (R2Photo, CGFloat, CGFloat) -> Cell  // photo, width, height

    @Environment(PhotoRatioCache.self) private var ratioCache

    var body: some View {
        let available = max(0, containerWidth - horizontalPadding * 2)
        let columnWidth = (available - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let cols = distributedColumns(columnWidth: columnWidth)

        HStack(alignment: .top, spacing: spacing) {
            ForEach(cols.indices, id: \.self) { idx in
                LazyVStack(spacing: spacing) {
                    ForEach(cols[idx], id: \.key) { photo in
                        let h = max(80, columnWidth / ratioCache.ratio(for: photo.key))
                        cell(photo, columnWidth, h)
                            .frame(width: columnWidth, height: h)
                            .clipped()
                    }
                }
                .frame(width: columnWidth)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, spacing)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func distributedColumns(columnWidth: CGFloat) -> [[R2Photo]] {
        var heights = Array(repeating: CGFloat(0), count: columns)
        var cols: [[R2Photo]] = Array(repeating: [], count: columns)
        for photo in photos {
            let ratio = ratioCache.ratio(for: photo.key)
            let h = columnWidth / max(0.1, ratio)
            let shortest = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
            cols[shortest].append(photo)
            heights[shortest] += h + spacing
        }
        return cols
    }
}

// MARK: - Masonry tile

struct PhotoMasonryTile: View {
    let photo: R2Photo
    let width: CGFloat
    let height: CGFloat
    @Environment(PhotoRatioCache.self) private var ratioCache

    var body: some View {
        Group {
            // Prefer the small thumbnail URL — afilmory webp thumbnails are
            // ~200-600 KB vs multi-MB originals, so the grid scrolls smoothly.
            if let url = URL(string: photo.displayUrl) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.15))) { phase in
                    tileContent(phase)
                }
            } else {
                placeholder
            }
        }
    }

    @ViewBuilder
    private func tileContent(_ phase: AsyncImagePhase) -> some View {
        switch phase {
        case .empty:
            placeholder.overlay(ProgressView().tint(AppColors.tertiary))
        case .success(let image):
            image
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .background(MeasureAspect(image: image, photoKey: photo.key))
        case .failure:
            placeholder.overlay(
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.tertiary)
            )
        @unknown default:
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle().fill(AppColors.surface)
    }
}

/// Hidden helper that captures the loaded image's intrinsic aspect ratio and
/// writes it into the shared cache so subsequent renders use the right height.
private struct MeasureAspect: View {
    let image: Image
    let photoKey: String
    @Environment(PhotoRatioCache.self) private var ratioCache

    var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: AspectKey.self, value: geo.size)
                }
            )
            .opacity(0)
            .onPreferenceChange(AspectKey.self) { size in
                guard size.width > 1, size.height > 1 else { return }
                Task { @MainActor in
                    ratioCache.set(size.width / size.height, for: photoKey)
                }
            }
    }
}

private struct AspectKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > value.width { value = next }
    }
}
