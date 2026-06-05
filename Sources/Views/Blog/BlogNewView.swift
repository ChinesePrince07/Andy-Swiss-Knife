import SwiftUI
import PhotosUI

struct BlogNewView: View {
    let onCreated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var draft = BlogPostInput(
        title: "",
        date: BlogNewView.todayString(),
        description: "",
        content: "",
        pinned: false
    )
    @State private var slugOverride = ""
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploadingMedia = false

    var body: some View {
        _ = themeManager.current
        return ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("NEW POST")
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .kerning(1.4)
                        .foregroundStyle(AppColors.primary)

                    editorBlock(label: "Title") {
                        TextField("Post title", text: $draft.title)
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                            .textInputAutocapitalization(.sentences)
                    }
                    editorBlock(label: "Date") {
                        TextField("YYYY-MM-DD", text: $draft.date)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    editorBlock(label: "Slug (optional)") {
                        TextField("auto-from-title", text: $slugOverride)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    editorBlock(label: "Description") {
                        TextField("Short summary", text: $draft.description, axis: .vertical)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                            .lineLimit(1...3)
                    }
                    contentBlock
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.red)
                    }
                    saveButton
                    cancelButton
                }
                .padding(16)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await handlePicker(items) }
        }
    }

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CONTENT (MARKDOWN)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.tertiary)
                Spacer()
                if uploadingMedia {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        Text("UPLOADING")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppColors.secondary)
                    }
                }
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 1, matching: .images) {
                    Text("+ IMAGE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1))
                }
                .disabled(uploadingMedia)
            }
            HairlineDivider()
            TextEditor(text: $draft.content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .scrollContentBackground(.hidden)
                .background(AppColors.surface)
                .frame(minHeight: 240)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
        }
    }

    private var saveButton: some View {
        Button { Task { await save() } } label: {
            HStack {
                Text(saving ? "PUBLISHING..." : "PUBLISH")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.surface)
                if saving {
                    Spacer()
                    ProgressView().tint(AppColors.surface)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.primary)
        }
        .buttonStyle(.plain)
        .disabled(saving || (draft.title.trimmingCharacters(in: .whitespaces).isEmpty && draft.content.trimmingCharacters(in: .whitespaces).isEmpty))
    }

    private var cancelButton: some View {
        Button { dismiss() } label: {
            Text("CANCEL")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func editorBlock<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            HairlineDivider()
            content()
                .padding(.horizontal, 10).padding(.vertical, 10)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil
        let trimmedSlug = slugOverride.trimmingCharacters(in: .whitespaces)
        do {
            let createdSlug = try await SiteClient.shared.createPost(draft, slug: trimmedSlug.isEmpty ? nil : trimmedSlug)
            onCreated(createdSlug)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        saving = false
    }

    private func handlePicker(_ items: [PhotosPickerItem]) async {
        defer { pickerItems = [] }
        guard let item = items.first else { return }
        uploadingMedia = true
        defer { uploadingMedia = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Couldn’t read the image."
                return
            }
            let fileName = "image-\(Int(Date().timeIntervalSince1970)).jpg"
            let url = try await SiteClient.shared.uploadInlineMedia(
                data: data,
                fileName: fileName,
                contentType: "image/jpeg"
            )
            let snippet = "\n\n<img src=\"\(url.absoluteString)\" alt=\"\" style=\"max-width: 50%; height: auto;\" />\n"
            draft.content += snippet
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension BlogNewView {
    static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    static func todayString() -> String { isoDayFormatter.string(from: .now) }
}
