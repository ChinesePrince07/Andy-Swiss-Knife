import SwiftUI
import PhotosUI

struct PhotoUploadView: View {
    let prefix: String
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var coordinator = PhotoUploadCoordinator()
    @State private var pickerItems: [PhotosPickerItem] = []
    // Keep PhotosPickerItem refs only — Data is loaded lazily per file during upload
    // so we don't pin every selected photo in memory at once.
    @State private var pendingItems: [String: PhotosPickerItem] = [:]
    @State private var folderName: String = ""

    var body: some View {
        _ = themeManager.current
        return ZStack {
            ThemedBackground()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("UPLOAD PICS")
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .kerning(1.4)
                        .foregroundStyle(AppColors.primary)
                    Spacer()
                    Button { dismiss() } label: {
                        Text("CLOSE")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }

                folderField

                pickerArea

                if !coordinator.items.isEmpty {
                    queueList
                }

                if let message = coordinator.message {
                    Text(message)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(message.contains("failed") || message.contains("Error") ? Color.red : AppColors.accent)
                }

                Spacer()

                uploadButton
            }
            .padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await ingest(items) }
        }
        .onAppear { folderName = prefix }
    }

    private var folderField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FOLDER (OPTIONAL)")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            HairlineDivider()
            TextField("e.g. trips/europe-2025", text: $folderName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 10).padding(.vertical, 10)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
        }
    }

    private var pickerArea: some View {
        PhotosPicker(selection: $pickerItems, selectionBehavior: .ordered, matching: .images) {
            VStack(spacing: 10) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 24))
                    .foregroundStyle(AppColors.primary)
                Text("PICK PHOTOS")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.primary)
                Text("HEIC, JPG, PNG, WebP, TIFF supported")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .overlay(
                Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .foregroundStyle(AppColors.primary)
            )
        }
        .disabled(coordinator.isUploading)
    }

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("QUEUE (\(coordinator.items.count))")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            HairlineDivider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(coordinator.items) { item in
                        HStack(spacing: 8) {
                            statusBadge(item)
                            Text(item.displayName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(AppColors.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            if !coordinator.isUploading {
                                Button { remove(item) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppColors.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { HairlineDivider() }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private func statusBadge(_ item: PhotoUploadCoordinator.Item) -> some View {
        let (label, color): (String, Color) = {
            switch item.status {
            case .pending:           return ("·",   AppColors.tertiary)
            case .uploading:         return ("…",   AppColors.primary)
            case .done:              return ("◆",   AppColors.accent)
            case .failed:            return ("✕",   Color.red)
            }
        }()
        return Text(label)
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(color)
            .frame(width: 14)
    }

    private var uploadButton: some View {
        Button {
            Task { await startUpload() }
        } label: {
            Text(coordinator.isUploading ? "UPLOADING..." : "UPLOAD \(coordinator.items.count) PHOTO\(coordinator.items.count == 1 ? "" : "S")")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(coordinator.items.isEmpty || coordinator.isUploading ? AppColors.tertiary : AppColors.primary)
        }
        .buttonStyle(.plain)
        .disabled(coordinator.items.isEmpty || coordinator.isUploading)
    }

    private func ingest(_ items: [PhotosPickerItem]) async {
        defer { pickerItems = [] }
        // afilmory's builder watches `photos/original/` — uploads land there so
        // it auto-generates thumbnails and includes the photo in the next build.
        let folder = folderName.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePrefix = "photos/original"
        let folderPath = folder.isEmpty ? basePrefix : "\(basePrefix)/\(folder)"
        for item in items {
            let suggestedName = "image-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).jpg"
            let key = "\(folderPath)/\(suggestedName)"
            pendingItems[key] = item
            coordinator.append(fileName: key, displayName: suggestedName, contentType: "image/jpeg")
        }
    }

    private func remove(_ item: PhotoUploadCoordinator.Item) {
        pendingItems.removeValue(forKey: item.fileName)
        coordinator.remove(item)
    }

    private func startUpload() async {
        let snapshot = pendingItems
        await coordinator.upload { item in
            guard let pickerItem = snapshot[item.fileName] else { throw SiteClientError.unknown }
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                throw SiteClientError.decoding
            }
            return data
        }
        if coordinator.items.allSatisfy({ if case .done = $0.status { return true } else { return false } }) {
            onComplete()
            dismiss()
        }
    }
}
