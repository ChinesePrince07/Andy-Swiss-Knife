import SwiftUI
import PhotosUI

enum PhotoSort: String, CaseIterable, Identifiable {
    case newest, oldest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "NEWEST"
        case .oldest: return "OLDEST"
        }
    }
}

/// Masonry column count. `auto` resolves from the container width so the grid
/// matches afilmory's column behavior; the numbered cases pin a fixed count.
enum PhotoColumns: String, CaseIterable, Identifiable {
    case auto, two = "2", three = "3", four = "4", five = "5"

    var id: String { rawValue }
    var label: String { self == .auto ? "AUTO" : rawValue }

    func resolved(width: CGFloat) -> Int {
        switch self {
        case .auto:  return min(5, max(2, Int((width / 180).rounded())))
        case .two:   return 2
        case .three: return 3
        case .four:  return 4
        case .five:  return 5
        }
    }
}

struct PhotoGalleryView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var photos: [R2Photo] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var prefixFilter: String = ""
    @State private var showingUpload = false
    @State private var selectionMode = false
    @State private var selected = Set<String>()
    @State private var pendingDelete = false
    @State private var showingAlbums = false
    @State private var showingAddToAlbum = false
    @AppStorage("photos.sort.v1") private var sortRaw: String = PhotoSort.newest.rawValue
    @AppStorage("photos.columns.v1") private var columnsRaw: String = PhotoColumns.auto.rawValue

    private var sort: PhotoSort { PhotoSort(rawValue: sortRaw) ?? .newest }
    private var columnChoice: PhotoColumns { PhotoColumns(rawValue: columnsRaw) ?? .auto }

    var body: some View {
        _ = themeManager.current
        return Group {
            if !SiteAuth.shared.isAuthed {
                lockedView
            } else {
                authedBody
            }
        }
        .background(AppColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if SiteAuth.shared.isAuthed, photos.isEmpty { await refresh() }
        }
        .sheet(isPresented: $showingUpload, onDismiss: { Task { await refresh() } }) {
            NavigationStack {
                PhotoUploadView(prefix: prefixFilter) { Task { await refresh() } }
            }
        }
        .alert("Delete \(selected.count) photo\(selected.count == 1 ? "" : "s")?", isPresented: $pendingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deleteSelection() } }
        } message: {
            Text("Removes from R2 and triggers an afilmory rebuild. Can't be undone.")
        }
        .sheet(isPresented: $showingAddToAlbum) {
            AddToAlbumSheet(keys: Array(selected)) {
                selectionMode = false
                selected.removeAll()
            }
        }
    }

    private var authedBody: some View {
        VStack(spacing: 0) {
            header
            if showingAlbums {
                AlbumsView()
            } else {
                toolbar
                sortBar
                content
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Rectangle().fill(AppColors.primary).frame(width: 3, height: 16)
            chip("PHOTOS", selected: !showingAlbums) { showingAlbums = false }
            chip("ALBUMS", selected: showingAlbums) { showingAlbums = true }
            Spacer()
            if !showingAlbums {
                Button { showingUpload = true } label: {
                    Text("+ UPLOAD")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(AppColors.surface)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.tertiary)
                TextField("prefix/", text: $prefixFilter)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { Task { await refresh() } }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(AppColors.surface)
            .overlay(Rectangle().strokeBorder(AppColors.hairline, lineWidth: 1))

            Button {
                if selectionMode {
                    selectionMode = false
                    selected.removeAll()
                } else {
                    selectionMode = true
                }
            } label: {
                Text(selectionMode ? "DONE" : "SELECT")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            if selectionMode && !selected.isEmpty {
                Button { showingAddToAlbum = true } label: {
                    Text("+ ALBUM")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(AppColors.surface)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(AppColors.primary)
                }
                .buttonStyle(.plain)
                Button { pendingDelete = true } label: {
                    Text("DELETE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                groupLabel("SORT")
                ForEach(PhotoSort.allCases) { option in
                    chip(option.label, selected: option == sort) { sortRaw = option.rawValue }
                }

                Rectangle()
                    .fill(AppColors.hairline)
                    .frame(width: 1, height: 16)
                    .padding(.horizontal, 4)

                groupLabel("COLS")
                ForEach(PhotoColumns.allCases) { option in
                    chip(option.label, selected: option == columnChoice) { columnsRaw = option.rawValue }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .kerning(1.2)
            .foregroundStyle(AppColors.tertiary)
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .kerning(0.8)
                .foregroundStyle(selected ? AppColors.surface : AppColors.primary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(selected ? AppColors.primary : Color.clear)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private var sortedPhotos: [R2Photo] {
        photos.sorted { a, b in
            switch sort {
            case .newest:
                return a.sortDate > b.sortDate
            case .oldest:
                return a.sortDate < b.sortDate
            }
        }
    }

    private var content: some View {
        Group {
            if loading && photos.isEmpty {
                ProgressView().tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                errorView(errorMessage)
            } else if photos.isEmpty {
                emptyState
            } else {
                grid
            }
        }
    }

    private var grid: some View {
        GeometryReader { geo in
            ScrollView {
                PhotoMasonry(photos: sortedPhotos, containerWidth: geo.size.width, columns: columnChoice.resolved(width: geo.size.width), spacing: 2, horizontalPadding: 2) { photo, w, h in
                    masonryCell(photo: photo, width: w, height: h)
                }
            }
            .refreshable { await refresh() }
        }
    }

    @ViewBuilder
    private func masonryCell(photo: R2Photo, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = selected.contains(photo.key)
        let cell = ZStack(alignment: .topTrailing) {
            PhotoMasonryTile(photo: photo, width: width, height: height)
            Rectangle()
                .strokeBorder(isSelected ? AppColors.accent : AppColors.hairline.opacity(0.5), lineWidth: isSelected ? 3 : 0.5)
            if selectionMode {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? AppColors.accent : .white)
                    .padding(4)
                    .background(Color.black.opacity(0.35))
            }
        }
        if selectionMode {
            Button {
                if isSelected { selected.remove(photo.key) } else { selected.insert(photo.key) }
            } label: { cell }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                PhotoDetailView(photo: photo) { Task { await refresh() } }
            } label: { cell }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.tertiary)
            Text("NO PHOTOS YET")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            Text(prefixFilter.isEmpty ? "Tap + UPLOAD to add some." : "No photos under that prefix.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("LOAD FAILED")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(Color.red)
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button { Task { await refresh() } } label: {
                Text("RETRY")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.surface)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.primary)
            Text("LINK YOUR SITE")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(AppColors.primary)
            Text("Add your publish secret in Settings → Publishing to upload to afilmory.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            NavigationLink {
                PublishingSettingsView()
            } label: {
                Text("OPEN PUBLISHING SETTINGS →")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.surface)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        loading = true
        errorMessage = nil
        do {
            let prefix = prefixFilter.trimmingCharacters(in: .whitespaces)
            photos = try await SiteClient.shared.listR2Photos(prefix: prefix.isEmpty ? nil : prefix)
            // Seed aspect ratios from the manifest so the masonry lays out
            // immediately instead of reflowing as each thumbnail loads.
            for photo in photos {
                if let ratio = photo.aspectRatio {
                    PhotoRatioCache.shared.set(CGFloat(ratio), for: photo.key)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }

    private func deleteSelection() async {
        let keys = Array(selected)
        do {
            try await SiteClient.shared.deleteR2Photos(keys: keys, triggerDeploy: true)
            selected.removeAll()
            selectionMode = false
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
