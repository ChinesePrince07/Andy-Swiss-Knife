import SwiftUI
import PhotosUI

struct BlogEditView: View {
    let slug: String
    let onSaved: () -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var loaded: BlogPostDetail?
    @State private var draft: BlogPostInput = BlogPostInput(title: "", date: "", description: "", content: "", pinned: false)
    @State private var loading = true
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var showDeleteConfirm = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploadingMedia = false

    var body: some View {
        _ = themeManager.current
        return ZStack {
            ThemedBackground()
            if loading {
                ProgressView().tint(AppColors.primary)
            } else if let errorMessage {
                errorView(errorMessage)
            } else {
                editorBody
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Delete post?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deletePost() } }
        } message: {
            Text("This permanently removes \(slug). It can't be undone.")
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await handlePicker(items) }
        }
    }

    private var editorBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                titleField
                metaRow
                descriptionField
                contentField
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                }
                actionRow
            }
            .padding(16)
        }
    }

    private var titleField: some View {
        editorBlock(label: "Title") {
            TextField("Post title", text: $draft.title)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
        }
    }

    private var metaRow: some View {
        HStack(alignment: .top, spacing: 10) {
            editorBlock(label: "Date") {
                TextField("YYYY-MM-DD", text: $draft.date)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("PIN")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.tertiary)
                HairlineDivider()
                Button { draft.pinned.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: draft.pinned ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                        Text(draft.pinned ? "PINNED" : "PIN")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .kerning(1.0)
                    }
                    .foregroundStyle(draft.pinned ? AppColors.surface : AppColors.primary)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(draft.pinned ? AppColors.primary : Color.clear)
                    .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var descriptionField: some View {
        editorBlock(label: "Description") {
            TextField("Short summary", text: $draft.description, axis: .vertical)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...3)
        }
    }

    private var contentField: some View {
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
                .frame(minHeight: 260)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            Button { Task { await save() } } label: {
                HStack {
                    Text(saving ? "SAVING..." : "SAVE")
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
            .disabled(saving || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)

            Button { showDeleteConfirm = true } label: {
                Text("DELETE POST")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(Rectangle().strokeBorder(Color.red, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text("LOAD FAILED")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(Color.red)
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
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

    // MARK: - Actions

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            let detail = try await SiteClient.shared.loadPost(slug: slug)
            loaded = detail
            draft = BlogPostInput(
                title: detail.title,
                date: detail.date,
                description: detail.description,
                content: detail.content,
                pinned: detail.pinned
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }

    private func save() async {
        saving = true
        statusMessage = nil
        do {
            try await SiteClient.shared.savePost(slug: slug, input: draft)
            statusMessage = "Saved ◆"
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
        saving = false
    }

    private func deletePost() async {
        do {
            try await SiteClient.shared.deletePost(slug: slug)
            onDeleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handlePicker(_ items: [PhotosPickerItem]) async {
        defer { pickerItems = [] }
        guard let item = items.first else { return }
        uploadingMedia = true
        defer { uploadingMedia = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                statusMessage = "Couldn’t read the image."
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
            statusMessage = "Image inserted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
