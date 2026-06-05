import SwiftUI
import MapKit

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

    // EXIF state
    @State private var exif: R2PhotoExif?
    @State private var exifLoading = true
    @State private var exifDate: Date = .now
    @State private var exifHasDate = false
    @State private var exifLatText: String = ""
    @State private var exifLonText: String = ""
    @State private var exifSaving = false
    @State private var exifSaved = false
    @State private var showMapPicker = false

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
                        exifBlock
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
        .task { await loadExif() }
        .alert("Delete photo?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await deletePhoto() } }
        } message: {
            Text("Removes \(photo.key) from R2 and triggers a rebuild.")
        }
        .sheet(isPresented: $showMove) {
            moveSheet
        }
        .sheet(isPresented: $showMapPicker) {
            ExifMapPicker(
                latitude: Double(exifLatText.trimmingCharacters(in: .whitespaces)),
                longitude: Double(exifLonText.trimmingCharacters(in: .whitespaces))
            ) { coord in
                exifLatText = String(format: "%.6f", coord.latitude)
                exifLonText = String(format: "%.6f", coord.longitude)
            }
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
        // Show the full original here — the user is inspecting a single photo
        // and bandwidth is fine for one image.
        AsyncImage(url: URL(string: photo.url)) { phase in
            switch phase {
            case .empty:
                Rectangle().fill(AppColors.surface).overlay(ProgressView().tint(AppColors.primary))
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Rectangle().fill(AppColors.surface).overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(AppColors.tertiary)
                )
            @unknown default:
                Rectangle().fill(AppColors.surface)
            }
        }
        .aspectRatio(contentMode: .fit)
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

    private var exifBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EXIF")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.tertiary)
                Spacer()
                if exifLoading {
                    ProgressView().scaleEffect(0.6)
                }
                if exifSaved {
                    Text("SAVED ◆")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                }
            }
            HairlineDivider()

            if !isJpegEditable {
                Text("EXIF editing currently supports JPEG only.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
            } else {
                exifCameraReadout
                exifDateRow
                exifLocationRow
                exifSaveButton
            }
        }
    }

    private var isJpegEditable: Bool {
        photo.key.lowercased().hasSuffix(".jpg") || photo.key.lowercased().hasSuffix(".jpeg")
    }

    private var exifCameraReadout: some View {
        let parts = [exif?.make, exif?.model, exif?.lens].compactMap { $0 }.filter { !$0.isEmpty }
        let label = parts.isEmpty ? "—" : parts.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 8) {
            Text("CAMERA")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(AppColors.tertiary)
                .frame(width: 70, alignment: .leading)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var exifDateRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("DATE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(AppColors.tertiary)
                .frame(width: 70, alignment: .leading)
            Toggle("", isOn: $exifHasDate)
                .labelsHidden()
                .tint(AppColors.primary)
            DatePicker("", selection: $exifDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .disabled(!exifHasDate)
        }
        .padding(.vertical, 4)
    }

    private var exifLocationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LATITUDE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.tertiary)
                    .frame(width: 70, alignment: .leading)
                TextField("e.g. 41.987", text: $exifLatText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1))
            }
            HStack {
                Text("LONGITUDE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.tertiary)
                    .frame(width: 70, alignment: .leading)
                TextField("e.g. -72.625", text: $exifLonText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1))
            }
            Button { showMapPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.system(size: 11))
                    Text("PICK ON MAP")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .kerning(0.8)
                }
                .foregroundStyle(AppColors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var exifSaveButton: some View {
        Button {
            Task { await saveExif() }
        } label: {
            Text(exifSaving ? "SAVING EXIF..." : "SAVE EXIF")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(exifSaving ? AppColors.tertiary : AppColors.primary)
        }
        .buttonStyle(.plain)
        .disabled(exifSaving)
        .padding(.top, 4)
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

    private func loadExif() async {
        exifLoading = true
        defer { exifLoading = false }
        guard isJpegEditable else { return }
        do {
            let result = try await SiteClient.shared.loadExif(key: photo.key)
            exif = result
            if let dateString = result.date, let parsed = Self.isoFormatter.date(from: dateString) {
                exifDate = parsed
                exifHasDate = true
            } else {
                exifHasDate = false
            }
            if let lat = result.latitude { exifLatText = String(lat) }
            if let lon = result.longitude { exifLonText = String(lon) }
        } catch {
            // Don't surface — EXIF read is best-effort
        }
    }

    private func saveExif() async {
        exifSaving = true
        exifSaved = false
        defer { exifSaving = false }

        let lat = Double(exifLatText.trimmingCharacters(in: .whitespaces))
        let lon = Double(exifLonText.trimmingCharacters(in: .whitespaces))
        let dateString = exifHasDate ? Self.isoFormatter.string(from: exifDate) : nil

        do {
            let updated = try await SiteClient.shared.updateExif(
                key: photo.key,
                date: dateString,
                latitude: lat,
                longitude: lon,
                triggerDeploy: true
            )
            exif = updated
            exifSaved = true
            onMutated()
        } catch {
            self.error = error.localizedDescription
        }
    }

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

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

// MARK: - Map picker

struct ExifMapPicker: View {
    let initialLatitude: Double?
    let initialLongitude: Double?
    let onPick: (CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition

    init(latitude: Double?, longitude: Double?, onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        self.initialLatitude = latitude
        self.initialLongitude = longitude
        self.onPick = onPick

        if let lat = latitude, let lon = longitude,
           (-90...90).contains(lat), (-180...180).contains(lon) {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            _pinCoordinate = State(initialValue: coord)
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )))
        } else {
            _pinCoordinate = State(initialValue: nil)
            // Default: world view
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
            )))
        }
    }

    var body: some View {
        _ = themeManager.current
        return ZStack {
            ThemedBackground()
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("PICK LOCATION")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(AppColors.primary)

                    Spacer()

                    Button {
                        if let coord = pinCoordinate {
                            onPick(coord)
                        }
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(pinCoordinate != nil ? AppColors.accent : AppColors.tertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(pinCoordinate == nil)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .overlay(alignment: .bottom) { HairlineDivider() }

                // Coordinate readout
                if let coord = pinCoordinate {
                    HStack(spacing: 12) {
                        Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                        Spacer()
                        Button {
                            pinCoordinate = nil
                        } label: {
                            Text("CLEAR")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .kerning(0.8)
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .overlay(alignment: .bottom) { HairlineDivider() }
                } else {
                    Text("TAP MAP TO PLACE PIN")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(AppColors.tertiary)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { HairlineDivider() }
                }

                // Map
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        if let coord = pinCoordinate {
                            Annotation("", coordinate: coord) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                    }
                    .mapStyle(.standard)
                    .onTapGesture { screenPoint in
                        if let coord = proxy.convert(screenPoint, from: .local) {
                            pinCoordinate = coord
                        }
                    }
                }
            }
        }
    }
}
