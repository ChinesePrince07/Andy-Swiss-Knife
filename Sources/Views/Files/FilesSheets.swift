import SwiftUI
import QuickLook
import PhotosUI
import UniformTypeIdentifiers

// MARK: - File Preview (full-screen, zoom + share)

struct FilePreviewSheet: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let ql = QLPreviewController()
        ql.dataSource = context.coordinator
        context.coordinator.previewController = ql

        let done = UIBarButtonItem(title: "Done", style: .done,
                                   target: context.coordinator,
                                   action: #selector(Coordinator.handleDismiss))
        let share = UIBarButtonItem(barButtonSystemItem: .action,
                                    target: context.coordinator,
                                    action: #selector(Coordinator.handleShare(_:)))
        ql.navigationItem.leftBarButtonItem = done
        ql.navigationItem.rightBarButtonItem = share

        return UINavigationController(rootViewController: ql)
    }

    func updateUIViewController(_ nav: UINavigationController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url, onDismiss: onDismiss) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        let onDismiss: () -> Void
        weak var previewController: QLPreviewController?

        init(url: URL, onDismiss: @escaping () -> Void) { self.url = url; self.onDismiss = onDismiss }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }

        @objc func handleDismiss() { onDismiss() }

        @objc func handleShare(_ sender: UIBarButtonItem) {
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            av.popoverPresentationController?.barButtonItem = sender
            previewController?.present(av, animated: true)
        }
    }
}

// MARK: - File Action Sheet (matches design: Open / Rename / Move / Share / Star / Download / Delete / Cancel)

struct FileActionSheet: View {
    @Binding var isPresented: Bool
    let item: DriveItem
    let isAdmin: Bool
    let onOpen: () -> Void
    let onRename: () -> Void
    let onMove: () -> Void
    let onShare: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    @State private var starred: Bool = false
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                DriveFileGlyph(item: item, size: 44)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(2)
                    Text(headerMeta)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.tertiary)
                }
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(16)

            HairlineDivider()

            ScrollView {
                VStack(spacing: 0) {
                    actionRow(label: "OPEN FILE", icon: "arrow.up.right.square") {
                        onOpen(); isPresented = false
                    }
                    HairlineDivider()

                    if isAdmin {
                        actionRow(label: "RENAME", icon: "pencil") {
                            onRename(); isPresented = false
                        }
                        HairlineDivider()
                        actionRow(label: "MOVE…", icon: "folder") {
                            onMove(); isPresented = false
                        }
                        HairlineDivider()
                    }

                    actionRow(label: "SHARE / GET LINK", icon: "square.and.arrow.up") {
                        onShare(); isPresented = false
                    }
                    HairlineDivider()

                    actionRow(label: starred ? "UNSTAR" : "STAR", icon: starred ? "star.slash" : "star") {
                        UserDefaults.standard.toggleStar(path: item.id)
                        starred.toggle()
                    }
                    HairlineDivider()

                    actionRow(label: "DOWNLOAD", icon: "arrow.down.circle") {
                        onDownload(); isPresented = false
                    }
                    HairlineDivider()

                    if isAdmin {
                        actionRow(label: "DELETE", icon: "trash", destructive: true) {
                            onDelete(); isPresented = false
                        }
                        HairlineDivider()
                    }

                    Button { isPresented = false } label: {
                        Text("CANCEL")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(AppColors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(AppColors.background)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(0)
        .presentationDragIndicator(.hidden)
        .onAppear { starred = UserDefaults.standard.isStarred(path: item.id) }
    }

    @ViewBuilder
    private func actionRow(label: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(destructive ? Color.red : AppColors.primary)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(destructive ? Color.red : AppColors.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var headerMeta: String {
        var parts: [String] = []
        if let date = item.modified {
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
            parts.append(f.string(from: date))
        }
        if !item.isDirectory && item.size > 0 {
            if item.size < 1_048_576 { parts.append(String(format: "%.0f KB", Double(item.size) / 1024)) }
            else { parts.append(String(format: "%.1f MB", Double(item.size) / 1_048_576)) }
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - New Folder Sheet

struct NewFolderSheet: View {
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    @State private var name = ""
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return VStack(alignment: .leading, spacing: 0) {
            sheetHeader(title: "NEW FOLDER") { isPresented = false }
            HairlineDivider()
            inputField(placeholder: "Folder name", text: $name)
            HairlineDivider()
            actionButton(title: "CREATE", disabled: name.trimmed.isEmpty) {
                onCreate(name.trimmed); isPresented = false
            }
        }
        .background(AppColors.background)
        .presentationDetents([.height(220)])
        .presentationCornerRadius(0)
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Rename Sheet

struct RenameSheet: View {
    @Binding var isPresented: Bool
    let item: DriveItem
    let onRename: (String) -> Void

    @State private var name: String
    @Environment(ThemeManager.self) private var themeManager

    init(isPresented: Binding<Bool>, item: DriveItem, onRename: @escaping (String) -> Void) {
        _isPresented = isPresented; self.item = item; self.onRename = onRename
        _name = State(initialValue: item.name)
    }

    var body: some View {
        _ = themeManager.current
        return VStack(alignment: .leading, spacing: 0) {
            sheetHeader(title: "RENAME") { isPresented = false }
            HairlineDivider()
            inputField(placeholder: "Name", text: $name)
            HairlineDivider()
            actionButton(title: "RENAME", disabled: name.trimmed.isEmpty || name.trimmed == item.name) {
                onRename(name.trimmed); isPresented = false
            }
        }
        .background(AppColors.background)
        .presentationDetents([.height(220)])
        .presentationCornerRadius(0)
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Move Sheet

struct MoveSheet: View {
    @Binding var isPresented: Bool
    let item: DriveItem
    let onMove: (String) -> Void

    @State private var destination = ""
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return VStack(alignment: .leading, spacing: 0) {
            sheetHeader(title: "MOVE TO") { isPresented = false }
            HairlineDivider()
            Text("Destination path (blank = root)")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            inputField(placeholder: "Folder path", text: $destination)
            HairlineDivider()
            actionButton(title: "MOVE") {
                onMove(destination.trimmed); isPresented = false
            }
        }
        .background(AppColors.background)
        .presentationDetents([.height(260)])
        .presentationCornerRadius(0)
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Upload Options Sheet

struct UploadOptionsSheet: View {
    @Binding var isPresented: Bool
    let onFilePicker: () -> Void
    let onPhotoPicker: () -> Void
    let onCamera: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return VStack(spacing: 0) {
            Text("UPLOAD")
                .font(AppType.sectionLabel)
                .kerning(1.2)
                .foregroundStyle(AppColors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            HairlineDivider()
            optionRow(icon: "doc.badge.plus", label: "FROM FILES")  { onFilePicker(); isPresented = false }
            HairlineDivider()
            optionRow(icon: "photo",          label: "FROM PHOTOS") { onPhotoPicker(); isPresented = false }
            HairlineDivider()
            optionRow(icon: "camera",         label: "CAMERA")      { onCamera(); isPresented = false }
        }
        .background(AppColors.background)
        .presentationDetents([.height(230)])
        .presentationCornerRadius(0)
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func optionRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Admin Login Sheet

struct AdminLoginSheet: View {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void

    @State private var password = ""
    @State private var failed = false
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return VStack(alignment: .leading, spacing: 0) {
            sheetHeader(title: "ADMIN LOGIN") { isPresented = false }
            HairlineDivider()

            if failed {
                Text("Incorrect password")
                    .font(AppType.caption)
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            SecureField("Password", text: $password)
                .font(AppType.body)
                .foregroundStyle(AppColors.primary)
                .padding(14)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.hairline, lineWidth: 1))
                .padding(16)

            HairlineDivider()
            actionButton(title: "LOGIN", disabled: password.isEmpty) {
                if DriveAdmin.shared.login(password: password) {
                    isPresented = false
                    onSuccess()
                } else {
                    failed = true
                    password = ""
                }
            }
        }
        .background(AppColors.background)
        .presentationDetents([.height(240)])
        .presentationCornerRadius(0)
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Share Activity Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Camera Sheet

struct CameraSheet: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

// MARK: - Shared helpers

@MainActor
private func sheetHeader(title: String, onDismiss: @escaping () -> Void) -> some View {
    HStack {
        Text(title)
            .font(AppType.sectionLabel)
            .kerning(1.2)
            .foregroundStyle(AppColors.primary)
        Spacer()
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.secondary)
        }
    }
    .padding(16)
}

@MainActor
private func inputField(placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
        .font(AppType.body)
        .foregroundStyle(AppColors.primary)
        .padding(14)
        .background(AppColors.surface)
        .overlay(Rectangle().strokeBorder(AppColors.hairline, lineWidth: 1))
        .padding(16)
}

@MainActor
private func actionButton(title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(AppType.bodyMedium)
            .foregroundStyle(AppColors.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? AppColors.tertiary : AppColors.primary)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .padding(16)
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
