import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct FilesView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var currentPath = ""
    @State private var pathSegments: [String] = []
    @State private var items: [DriveItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchText = ""

    @State private var selectedItems = Set<String>()
    @State private var isSelectMode = false
    @State private var sortMode: FileSortMode = .name
    @State private var sortAscending = true

    @State private var actionItem: DriveItem? = nil
    @State private var showActionSheet = false
    @State private var showRenameSheet = false
    @State private var showMoveSheet = false
    @State private var showNewFolderSheet = false
    @State private var showUploadOptions = false
    @State private var showFABMenu = false
    @State private var showAdminLogin = false

    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photosPickerItem: PhotosPickerItem? = nil

    @State private var previewURL: URL? = nil
    @State private var shareURL: URL? = nil
    @State private var downloadingItemID: String? = nil
    @State private var actionAfterDismiss: (() -> Void)? = nil

    private var admin: DriveAdmin { DriveAdmin.shared }

    private var visibleItems: [DriveItem] {
        let filtered = searchText.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted { a, b in
            let result: Bool
            switch sortMode {
            case .name: result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .date: result = (a.modified ?? .distantPast) > (b.modified ?? .distantPast)
            case .size: result = a.size > b.size
            case .type: result = a.fileType.label < b.fileType.label
            }
            return sortAscending ? result : !result
        }
    }

    var body: some View {
        _ = themeManager.current
        return ZStack(alignment: .bottomTrailing) {
            ThemedBackground()

            VStack(spacing: 0) {
                BreadcrumbBar(segments: pathSegments) { navigateTo(index: $0) }
                    .environment(themeManager)
                folderTitleBlock
                DriveSearchBar(text: $searchText)
                    .environment(themeManager)
                sortBar

                if isSelectMode && !selectedItems.isEmpty {
                    bulkActionBar
                }

                contentBody
            }

            VStack(spacing: 10) {
                if !isSelectMode && admin.isAdmin {
                    fabButton
                }
                adminButton
            }
            .padding(.trailing, 20)
            .padding(.bottom, 12)
        }
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width > 80 && abs(value.translation.height) < 100 {
                        goBack()
                    }
                }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showActionSheet, onDismiss: {
            let pending = actionAfterDismiss
            actionAfterDismiss = nil
            pending?()
        }) {
            if let item = actionItem {
                FileActionSheet(
                    isPresented: $showActionSheet,
                    item: item,
                    isAdmin: admin.isAdmin,
                    onOpen:     { actionAfterDismiss = { openFile(item) } },
                    onRename:   { actionAfterDismiss = { showRenameSheet = true } },
                    onMove:     { actionAfterDismiss = { showMoveSheet = true } },
                    onShare:    { actionAfterDismiss = { downloadForShare(item) } },
                    onDownload: { actionAfterDismiss = { downloadForShare(item) } },
                    onDelete:   { actionAfterDismiss = { deleteItem(item) } }
                )
                .environment(themeManager)
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            if let item = actionItem {
                RenameSheet(isPresented: $showRenameSheet, item: item) { renameItem(item, newName: $0) }
                    .environment(themeManager)
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            if let item = actionItem {
                MoveSheet(isPresented: $showMoveSheet, item: item) { moveItem(item, to: $0) }
                    .environment(themeManager)
            }
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet(isPresented: $showNewFolderSheet) { createFolder(name: $0) }
                .environment(themeManager)
        }
        .sheet(isPresented: $showUploadOptions) {
            UploadOptionsSheet(
                isPresented: $showUploadOptions,
                onFilePicker: { showFilePicker = true },
                onPhotoPicker: { showPhotoPicker = true },
                onCamera: { showCamera = true }
            )
            .environment(themeManager)
        }
        .sheet(isPresented: $showAdminLogin) {
            AdminLoginSheet(isPresented: $showAdminLogin) {}
                .environment(themeManager)
        }
        .fullScreenCover(isPresented: Binding(
            get: { previewURL != nil },
            set: { if !$0 { previewURL = nil } }
        )) {
            if let url = previewURL {
                FilePreviewSheet(url: url) { previewURL = nil }
            }
        }
        .sheet(item: Binding(
            get: { shareURL.map { IdentifiableURL($0) } },
            set: { shareURL = $0?.url }
        )) { ShareSheet(items: [$0.url]) }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { handleFileImport($0) }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, item in Task { await handlePhotosPicker(item) } }
        .sheet(isPresented: $showCamera) {
            CameraSheet { image in Task { await uploadImage(image) } }
        }
        .onAppear { load() }
        .refreshable { load() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !pathSegments.isEmpty {
                Button { goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(isSelectMode ? "DONE" : "SELECT") {
                isSelectMode.toggle()
                if !isSelectMode { selectedItems.removeAll() }
            }
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(AppColors.primary)
        }
    }

    // MARK: - Folder Title

    private var folderTitleBlock: some View {
        let title = pathSegments.last ?? "FILES"
        return HStack(spacing: 10) {
            Rectangle()
                .fill(AppColors.primary)
                .frame(width: 3, height: 16)
            Text(title.uppercased())
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppColors.background)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentBody: some View {
        if let error = errorMessage {
            errorState(error)
        } else if visibleItems.isEmpty && !isLoading {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    let folders = visibleItems.filter { $0.isDirectory }
                    let files   = visibleItems.filter { !$0.isDirectory }

                    if !folders.isEmpty {
                        sectionHeader("FOLDERS")
                        ForEach(folders) { item in itemRow(item); HairlineDivider() }
                    }
                    if !files.isEmpty {
                        sectionHeader("FILES")
                        ForEach(files) { item in itemRow(item); HairlineDivider() }
                    }
                }
                .padding(.bottom, 80)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack { SectionLabel(text: label); Spacer() }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func itemRow(_ item: DriveItem) -> some View {
        DriveFileRow(
            item: item,
            isSelected: selectedItems.contains(item.id),
            isDownloading: downloadingItemID == item.id,
            onTap: { handleTap(item) },
            onMore: { actionItem = item; showActionSheet = true }
        )
        .environment(themeManager)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColors.tertiary)
            Text(searchText.isEmpty ? "EMPTY" : "NO RESULTS")
                .font(AppType.sectionLabel)
                .kerning(1.5)
                .foregroundStyle(AppColors.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.red)
            Text(message)
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("RETRY") { load() }
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack(spacing: 0) {
            ForEach(FileSortMode.allCases) { mode in
                Button {
                    if sortMode == mode {
                        sortAscending.toggle()
                    } else {
                        sortMode = mode
                        sortAscending = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(mode.label)
                            .font(.system(size: 10, weight: sortMode == mode ? .heavy : .medium, design: .monospaced))
                            .foregroundStyle(sortMode == mode ? AppColors.primary : AppColors.tertiary)
                        if sortMode == mode {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .background(AppColors.surface)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    // MARK: - Bulk Action Bar

    private var bulkActionBar: some View {
        HStack(spacing: 0) {
            Text("\(selectedItems.count) SELECTED")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.surface)
                .padding(.horizontal, 16)
            Spacer()
            if admin.isAdmin {
                Button {
                    items.filter { selectedItems.contains($0.id) }.forEach { deleteItem($0) }
                    selectedItems.removeAll(); isSelectMode = false
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.red)
                        .padding(12)
                }
            }
        }
        .frame(height: 48)
        .background(AppColors.primary)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.surface).frame(height: 2)
        }
    }

    // MARK: - FAB

    private var fabButton: some View {
        VStack(spacing: 0) {
            if showFABMenu {
                VStack(alignment: .trailing, spacing: 8) {
                    fabMenuItem(label: "NEW FOLDER", icon: "folder.badge.plus") {
                        showNewFolderSheet = true; showFABMenu = false
                    }
                    fabMenuItem(label: "UPLOAD FILE", icon: "arrow.up.doc") {
                        showUploadOptions = true; showFABMenu = false
                    }
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { showFABMenu.toggle() }
            } label: {
                Image(systemName: showFABMenu ? "xmark" : "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.surface)
                    .frame(width: 54, height: 54)
                    .background(AppColors.primary)
                    .shadow(color: AppColors.primary.opacity(0.4), radius: 0, x: 4, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func fabMenuItem(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(AppColors.surface)
                    .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.surface)
                    .frame(width: 36, height: 36)
                    .background(AppColors.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Admin Button

    private var adminButton: some View {
        Button {
            if admin.isAdmin {
                admin.logout()
            } else {
                showAdminLogin = true
            }
        } label: {
            Image(systemName: admin.isAdmin ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(admin.isAdmin ? AppColors.surface : AppColors.tertiary)
                .frame(width: 40, height: 40)
                .background(admin.isAdmin ? AppColors.accent : AppColors.surface)
                .overlay(Rectangle().strokeBorder(admin.isAdmin ? AppColors.accent : AppColors.hairline, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func goBack() {
        guard !pathSegments.isEmpty else { return }
        searchText = ""
        pathSegments.removeLast()
        currentPath = pathSegments.joined(separator: "/")
        load()
    }

    private func navigateTo(index: Int) {
        searchText = ""
        if index == 0 { pathSegments = []; currentPath = "" }
        else { pathSegments = Array(pathSegments.prefix(index)); currentPath = pathSegments.joined(separator: "/") }
        load()
    }

    private func handleTap(_ item: DriveItem) {
        if isSelectMode {
            if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
            else { selectedItems.insert(item.id) }
        } else if item.isDirectory {
            searchText = ""
            pathSegments.append(item.name)
            currentPath = pathSegments.joined(separator: "/")
            load()
        } else {
            openFile(item)
        }
    }

    // MARK: - Data Operations

    private func load() {
        isLoading = true; errorMessage = nil
        Task {
            do {
                let loaded = try await WebDAVService.shared.list(path: currentPath)
                await MainActor.run { items = loaded; isLoading = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
            }
        }
    }

    private func openFile(_ item: DriveItem) {
        guard downloadingItemID == nil else { return }
        downloadingItemID = item.id
        Task {
            do {
                let url = try await WebDAVService.shared.download(path: item.id)
                await MainActor.run { previewURL = url; downloadingItemID = nil }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; downloadingItemID = nil }
            }
        }
    }

    private func downloadForShare(_ item: DriveItem) {
        guard downloadingItemID == nil else { return }
        downloadingItemID = item.id
        Task {
            do {
                let url = try await WebDAVService.shared.download(path: item.id)
                await MainActor.run { shareURL = url; downloadingItemID = nil }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; downloadingItemID = nil }
            }
        }
    }

    private func createFolder(name: String) {
        let path = currentPath.isEmpty ? name : "\(currentPath)/\(name)"
        Task {
            do { try await WebDAVService.shared.createFolder(path: path); load() }
            catch { await MainActor.run { errorMessage = error.localizedDescription } }
        }
    }

    private func deleteItem(_ item: DriveItem) {
        Task {
            do {
                try await WebDAVService.shared.delete(path: item.id)
                await MainActor.run { items.removeAll { $0.id == item.id } }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func renameItem(_ item: DriveItem, newName: String) {
        Task {
            do { try await WebDAVService.shared.rename(path: item.id, newName: newName); load() }
            catch { await MainActor.run { errorMessage = error.localizedDescription } }
        }
    }

    private func moveItem(_ item: DriveItem, to folder: String) {
        let newPath = folder.isEmpty ? item.name : "\(folder)/\(item.name)"
        Task {
            do { try await WebDAVService.shared.move(from: item.id, to: newPath); load() }
            catch { await MainActor.run { errorMessage = error.localizedDescription } }
        }
    }

    // MARK: - Upload

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            Task {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    let path = currentPath.isEmpty ? url.lastPathComponent : "\(currentPath)/\(url.lastPathComponent)"
                    do { try await WebDAVService.shared.upload(data: data, to: path); load() }
                    catch { await MainActor.run { errorMessage = error.localizedDescription } }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func handlePhotosPicker(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        let name = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
        let path = currentPath.isEmpty ? name : "\(currentPath)/\(name)"
        do { try await WebDAVService.shared.upload(data: data, to: path, mimeType: "image/jpeg"); load() }
        catch { await MainActor.run { errorMessage = error.localizedDescription } }
    }

    private func uploadImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let name = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
        let path = currentPath.isEmpty ? name : "\(currentPath)/\(name)"
        do { try await WebDAVService.shared.upload(data: data, to: path, mimeType: "image/jpeg"); load() }
        catch { await MainActor.run { errorMessage = error.localizedDescription } }
    }
}

// MARK: - Sort Mode

enum FileSortMode: String, CaseIterable, Identifiable {
    case name, date, size, type
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

// MARK: - Helpers

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
    init(_ url: URL) { self.url = url }
}
