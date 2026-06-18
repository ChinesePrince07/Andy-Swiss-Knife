import SwiftUI

/// The ALBUMS tab of PICS: a grid of afilmory albums with create + drill-in.
struct AlbumsView: View {
    @State private var albums: [Album] = []
    @State private var library: [R2Photo] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var creating = false
    @State private var newName = ""

    /// key -> photo, for resolving album covers.
    private var byKey: [String: R2Photo] {
        Dictionary(library.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        Group {
            if loading && albums.isEmpty {
                ProgressView().tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                errorView(errorMessage)
            } else {
                content
            }
        }
        .task { if albums.isEmpty { await refresh() } }
        .alert("New album", isPresented: $creating) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { newName = "" }
            Button("Create") { Task { await create() } }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 2)], spacing: 2) {
                Button { newName = ""; creating = true } label: { newCard }.buttonStyle(.plain)
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album, library: library) { Task { await refresh() } }
                    } label: { card(album) }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
        }
        .refreshable { await refresh() }
    }

    private func card(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                AppColors.surface
                if let cover = coverPhoto(album), let url = URL(string: cover.displayUrl) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                } else {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 22)).foregroundStyle(AppColors.tertiary)
                }
            }
            .frame(height: 130).clipped()
            VStack(alignment: .leading, spacing: 1) {
                Text(album.name.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced)).kerning(0.8)
                    .foregroundStyle(AppColors.primary).lineLimit(1)
                Text("\(album.photoKeys.count) PHOTO\(album.photoKeys.count == 1 ? "" : "S")")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
        }
        .overlay(Rectangle().strokeBorder(AppColors.hairline, lineWidth: 1))
    }

    private var newCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus").font(.system(size: 22, weight: .bold))
            Text("NEW ALBUM").font(.system(size: 10, weight: .heavy, design: .monospaced)).kerning(1.0)
        }
        .foregroundStyle(AppColors.primary)
        .frame(maxWidth: .infinity).frame(height: 130 + 34)
        .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
    }

    private func coverPhoto(_ album: Album) -> R2Photo? {
        if let ck = album.coverKey, let p = byKey[ck] { return p }
        if let first = album.photoKeys.first, let p = byKey[first] { return p }
        return nil
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("LOAD FAILED").font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.red)
            Text(message).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary).multilineTextAlignment(.center).padding(.horizontal, 24)
            Button { Task { await refresh() } } label: {
                Text("RETRY").font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.surface).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(AppColors.primary)
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refresh() async {
        loading = true; errorMessage = nil
        do {
            async let a = SiteClient.shared.listAlbums()
            async let p = SiteClient.shared.listR2Photos(prefix: nil)
            albums = try await a
            library = try await p
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }

    private func create() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
        guard !name.isEmpty else { return }
        do {
            _ = try await SiteClient.shared.createAlbum(name: name)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
