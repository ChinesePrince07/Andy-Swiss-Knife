import SwiftUI

/// One album: its photos, rename / set-cover / delete, and add/remove members.
struct AlbumDetailView: View {
    @State var album: Album
    let library: [R2Photo]
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectionMode = false
    @State private var coverMode = false
    @State private var selected = Set<String>()
    @State private var renaming = false
    @State private var newName = ""
    @State private var pendingDelete = false
    @State private var adding = false
    @State private var errorMessage: String?

    private var albumPhotos: [R2Photo] {
        let keys = Set(album.photoKeys)
        return library.filter { keys.contains($0.key) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if albumPhotos.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .background(AppColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Rename album", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { Task { await rename() } }
        }
        .alert("Delete album?", isPresented: $pendingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deleteAlbum() } }
        } message: { Text("Removes the album from the site. Photos are not deleted.") }
        .sheet(isPresented: $adding) {
            NavigationStack {
                AlbumPhotoPicker(album: album, library: library) { added in
                    if let added { album = added; onChanged() }
                    adding = false
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage).font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white).padding(8).background(Color.red).padding()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColors.primary).frame(width: 3, height: 16)
            Text(album.name.uppercased())
                .font(.system(size: 14, weight: .heavy, design: .monospaced)).kerning(1.2)
                .foregroundStyle(AppColors.primary).lineLimit(1).minimumScaleFactor(0.6)
            Spacer()
            if coverMode {
                Text("TAP A COVER").font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                Button("CANCEL") { coverMode = false }
                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(AppColors.primary)
            } else if selectionMode {
                if !selected.isEmpty {
                    Button("REMOVE") { Task { await removeSelected() } }
                        .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Color.red)
                }
                Button("DONE") { selectionMode = false; selected.removeAll() }
                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(AppColors.primary)
            } else {
                Button { adding = true } label: { barLabel("+ ADD") }.buttonStyle(.plain)
                Menu {
                    Button("Rename") { newName = album.name; renaming = true }
                    Button("Set cover") { coverMode = true }
                    Button("Select to remove") { selectionMode = true }
                    Button("Delete album", role: .destructive) { pendingDelete = true }
                } label: { Image(systemName: "ellipsis").font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.primary).padding(.horizontal, 4) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private func barLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 10, weight: .heavy, design: .monospaced)).kerning(0.8)
            .foregroundStyle(AppColors.surface).padding(.horizontal, 10).padding(.vertical, 6).background(AppColors.primary)
    }

    private var grid: some View {
        GeometryReader { geo in
            ScrollView {
                PhotoMasonry(photos: albumPhotos, containerWidth: geo.size.width,
                             columns: max(2, Int((geo.size.width / 180).rounded())), spacing: 2, horizontalPadding: 2) { photo, w, h in
                    cell(photo, w, h)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ photo: R2Photo, _ w: CGFloat, _ h: CGFloat) -> some View {
        let isSel = selected.contains(photo.key)
        let tile = ZStack(alignment: .topTrailing) {
            PhotoMasonryTile(photo: photo, width: w, height: h)
            Rectangle().strokeBorder(isSel ? AppColors.accent : AppColors.hairline.opacity(0.5), lineWidth: isSel ? 3 : 0.5)
            if selectionMode {
                Image(systemName: isSel ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(isSel ? AppColors.accent : .white)
                    .padding(4).background(Color.black.opacity(0.35))
            }
        }
        if coverMode {
            Button { Task { await setCover(photo.key) } } label: { tile }.buttonStyle(.plain)
        } else if selectionMode {
            Button { if isSel { selected.remove(photo.key) } else { selected.insert(photo.key) } } label: { tile }.buttonStyle(.plain)
        } else {
            NavigationLink { PhotoDetailView(photo: photo) { onChanged() } } label: { tile }.buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 28)).foregroundStyle(AppColors.tertiary)
            Text("EMPTY ALBUM").font(.system(size: 12, weight: .heavy, design: .monospaced)).kerning(1.2).foregroundStyle(AppColors.tertiary)
            Button { adding = true } label: { barLabel("+ ADD PHOTOS") }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rename() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        await mutate { try await SiteClient.shared.updateAlbum(id: album.id, name: name) }
    }
    private func setCover(_ key: String) async {
        coverMode = false
        await mutate { try await SiteClient.shared.updateAlbum(id: album.id, coverKey: key) }
    }
    private func removeSelected() async {
        let keys = Array(selected); selected.removeAll(); selectionMode = false
        await mutate { try await SiteClient.shared.updateAlbum(id: album.id, removeKeys: keys) }
    }
    private func deleteAlbum() async {
        do { try await SiteClient.shared.deleteAlbum(id: album.id); onChanged(); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
    private func mutate(_ op: () async throws -> Album) async {
        do { album = try await op(); onChanged() }
        catch { errorMessage = error.localizedDescription }
    }
}

/// Multi-select of library photos NOT already in the album → add to it.
private struct AlbumPhotoPicker: View {
    let album: Album
    let library: [R2Photo]
    let onDone: (Album?) -> Void

    @State private var selected = Set<String>()
    @State private var working = false

    private var candidates: [R2Photo] {
        let inAlbum = Set(album.photoKeys)
        return library.filter { !inAlbum.contains($0.key) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { onDone(nil) }
                Spacer()
                Text("ADD PHOTOS").font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundStyle(AppColors.primary)
                Spacer()
                Button("ADD \(selected.count)") { Task { await add() } }.disabled(selected.isEmpty || working)
            }
            .font(.system(size: 12, design: .monospaced)).padding()
            HairlineDivider()
            GeometryReader { geo in
                ScrollView {
                    PhotoMasonry(photos: candidates, containerWidth: geo.size.width,
                                 columns: max(2, Int((geo.size.width / 180).rounded())), spacing: 2, horizontalPadding: 2) { photo, w, h in
                        let isSel = selected.contains(photo.key)
                        Button {
                            if isSel { selected.remove(photo.key) } else { selected.insert(photo.key) }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                PhotoMasonryTile(photo: photo, width: w, height: h)
                                Rectangle().strokeBorder(isSel ? AppColors.accent : .clear, lineWidth: 3)
                                Image(systemName: isSel ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 18, weight: .bold)).foregroundStyle(isSel ? AppColors.accent : .white)
                                    .padding(4).background(Color.black.opacity(0.35))
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .background(AppColors.background)
    }

    private func add() async {
        working = true
        do { let updated = try await SiteClient.shared.updateAlbum(id: album.id, addKeys: Array(selected)); onDone(updated) }
        catch { onDone(nil) }
    }
}
