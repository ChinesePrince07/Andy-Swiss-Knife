import SwiftUI

/// Add the given photo `keys` to an existing album (tap one) or a new album.
struct AddToAlbumSheet: View {
    let keys: [String]
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var albums: [Album] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var creating = false
    @State private var newName = ""
    @State private var working = false

    var body: some View {
        NavigationStack {
            Group {
                if loading && albums.isEmpty {
                    ProgressView().tint(AppColors.primary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    list
                }
            }
            .background(AppColors.background)
            .navigationTitle("Add \(keys.count) to album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
            .task { if albums.isEmpty { await load() } }
            .alert("New album", isPresented: $creating) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Create") { Task { await createAndAdd() } }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white).padding(8).background(Color.red).padding()
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button { newName = ""; creating = true } label: {
                    row(systemImage: "plus", text: "NEW ALBUM", subtitle: nil)
                }.buttonStyle(.plain).disabled(working)
                HairlineDivider()
                ForEach(albums) { album in
                    Button { Task { await add(to: album) } } label: {
                        row(systemImage: "rectangle.stack", text: album.name.uppercased(),
                            subtitle: "\(album.photoKeys.count)")
                    }.buttonStyle(.plain).disabled(working)
                    HairlineDivider()
                }
            }
        }
    }

    private func row(systemImage: String, text: String, subtitle: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).font(.system(size: 14)).foregroundStyle(AppColors.primary).frame(width: 22)
            Text(text).font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundStyle(AppColors.primary)
            Spacer()
            if let subtitle {
                Text(subtitle).font(.system(size: 10, design: .monospaced)).foregroundStyle(AppColors.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func load() async {
        loading = true; errorMessage = nil
        do { albums = try await SiteClient.shared.listAlbums() }
        catch { errorMessage = error.localizedDescription }
        loading = false
    }

    private func add(to album: Album) async {
        working = true
        do { _ = try await SiteClient.shared.updateAlbum(id: album.id, addKeys: keys); onDone(); dismiss() }
        catch { errorMessage = error.localizedDescription; working = false }
    }

    private func createAndAdd() async {
        let name = newName.trimmingCharacters(in: .whitespaces); newName = ""
        guard !name.isEmpty else { return }
        working = true
        do { _ = try await SiteClient.shared.createAlbum(name: name, photoKeys: keys); onDone(); dismiss() }
        catch { errorMessage = error.localizedDescription; working = false }
    }
}
