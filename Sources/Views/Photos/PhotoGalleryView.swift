import SwiftUI
import PhotosUI

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
    }

    private var authedBody: some View {
        VStack(spacing: 0) {
            header
            toolbar
            content
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColors.primary).frame(width: 3, height: 16)
            Text(prefixFilter.isEmpty ? "PICS" : prefixFilter.uppercased())
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
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
        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos) { photo in
                    photoCell(photo)
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 2)
        }
        .refreshable { await refresh() }
    }

    @ViewBuilder
    private func photoCell(_ photo: R2Photo) -> some View {
        let isSelected = selected.contains(photo.key)
        let cell = ZStack(alignment: .topTrailing) {
            R2Thumbnail(photo: photo)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .overlay(
                    Rectangle().strokeBorder(isSelected ? AppColors.accent : AppColors.hairline, lineWidth: isSelected ? 3 : 0.5)
                )
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
