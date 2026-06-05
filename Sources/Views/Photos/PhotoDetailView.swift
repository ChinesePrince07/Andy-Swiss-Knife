import SwiftUI

struct PhotoDetailView: View {
    let photo: R2Photo
    let onMutated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var movePath: String = ""
    @State private var showDelete = false
    @State private var showMove = false
    @State private var error: String?
    @State private var working = false

    var body: some View {
        _ = themeManager.current
        return ZStack {
            ThemedBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        preview
                        metaBlock
                        actions
                        if let error {
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.red)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Delete photo?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deletePhoto() } }
        } message: {
            Text("Removes \(photo.key) from R2 and triggers a rebuild.")
        }
        .sheet(isPresented: $showMove) {
            moveSheet
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("BACK")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(photo.key.split(separator: "/").last.map(String.init) ?? photo.key)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var preview: some View {
        R2Thumbnail(photo: photo, large: true)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
    }

    private var metaBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INFO")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            HairlineDivider()
            metaRow("Key", photo.key)
            metaRow("Size", sizeString(photo.size))
            if let modified = photo.lastModified, !modified.isEmpty {
                metaRow("Updated", String(modified.prefix(19)).replacingOccurrences(of: "T", with: " "))
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(AppColors.tertiary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                movePath = photo.key
                showMove = true
            } label: {
                actionLabel("MOVE / RENAME", filled: false)
            }
            .buttonStyle(.plain)

            Button { showDelete = true } label: {
                actionLabel("DELETE", filled: true, destructive: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(_ text: String, filled: Bool, destructive: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundStyle(filled ? (destructive ? .white : AppColors.surface) : (destructive ? Color.red : AppColors.primary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? (destructive ? Color.red : AppColors.primary) : Color.clear)
            .overlay(Rectangle().strokeBorder(destructive ? Color.red : AppColors.primary, lineWidth: filled ? 0 : 1.5))
    }

    private var moveSheet: some View {
        ZStack {
            ThemedBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text("MOVE PHOTO")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.primary)
                Text("Edit the full key (folder + filename). Submitting copies the file and deletes the old key.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.secondary)

                TextField("trips/europe-2025/sunset.jpg", text: $movePath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(10)
                    .background(AppColors.surface)
                    .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))

                HStack(spacing: 10) {
                    Button { showMove = false } label: {
                        Text("CANCEL")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Button { Task { await movePhoto() } } label: {
                        Text(working ? "MOVING..." : "MOVE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppColors.surface)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(working || movePath.trimmingCharacters(in: .whitespaces).isEmpty || movePath == photo.key)
                }
            }
            .padding(20)
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(0)
    }

    private func sizeString(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    private func deletePhoto() async {
        working = true
        do {
            try await SiteClient.shared.deleteR2Photos(keys: [photo.key], triggerDeploy: true)
            onMutated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        working = false
    }

    private func movePhoto() async {
        working = true
        defer { working = false }
        let target = movePath.trimmingCharacters(in: .whitespaces)
        do {
            try await SiteClient.shared.moveR2Photo(from: photo.key, to: target, triggerDeploy: true)
            showMove = false
            onMutated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Async thumbnail

struct R2Thumbnail: View {
    let photo: R2Photo
    var large: Bool = false

    var body: some View {
        Group {
            if photo.url.isEmpty, let url = URL(string: "https://placehold.co/600x600/eee/000?text=No+URL") {
                AsyncImage(url: url) { phase in
                    placeholderOrImage(phase)
                }
            } else if let url = URL(string: photo.url) {
                AsyncImage(url: url) { phase in
                    placeholderOrImage(phase)
                }
            } else {
                placeholderTile
            }
        }
    }

    @ViewBuilder
    private func placeholderOrImage(_ phase: AsyncImagePhase) -> some View {
        switch phase {
        case .empty:
            placeholderTile.overlay(ProgressView().tint(AppColors.primary))
        case .success(let image):
            image.resizable().scaledToFill()
        case .failure:
            placeholderTile.overlay(
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(AppColors.tertiary)
            )
        @unknown default:
            placeholderTile
        }
    }

    private var placeholderTile: some View {
        Rectangle()
            .fill(AppColors.surface)
    }
}
