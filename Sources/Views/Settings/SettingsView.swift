import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    let services: Services

    @Environment(ThemeManager.self) private var themeManager
    @State private var menuSync: Date?
    @State private var eventsSync: Date?
    @State private var canvasSync: Date?
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRefreshing = false
    @State private var showingCalendarImport = false

    var body: some View {
        @Bindable var userSettings = UserSettings.shared
        return ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("SETTINGS")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .kerning(1.6)
                        .foregroundStyle(AppColors.primary)
                        .padding(.top, 2)

                    youSection(name: $userSettings.displayName)
                    themeSection
                    scheduleSection
                    layoutSection
                    canvasSection(url: $userSettings.canvasFeedURL)
                    athleticsSection
                    apExamsSection
                    countdownSection
                    eventsSection
                    syncSection
                    permissionsSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            readState()
            await readAuth()
        }
        .sheet(isPresented: $showingCalendarImport) {
            CalendarImportView()
        }
    }

    // MARK: - Sections

    private func youSection(name: Binding<String>) -> some View {
        settingsBlock(title: "You") {
            brutalField {
                TextField("Your name", text: name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .foregroundStyle(AppColors.primary)
            }
        }
    }

    private var themeSection: some View {
        settingsBlock(title: "Theme") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(Theme.all) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.select(theme)
                        }
                    } label: {
                        themeCell(theme)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }

    private var scheduleSection: some View {
        settingsBlock(title: "Schedule") {
            NavigationLink { ScheduleEditorView() } label: {
                brutalRow("My classes", value: "edit")
            }
        }
    }

    private var layoutSection: some View {
        settingsBlock(title: "Layout") {
            NavigationLink { DashboardLayoutEditor() } label: {
                brutalRow("Customize dashboard", value: "arrange")
            }
        }
    }

    private func canvasSection(url: Binding<String>) -> some View {
        settingsBlock(title: "Canvas feed") {
            brutalField {
                TextField("https://…instructure.com/feeds/calendars/user_….ics",
                          text: url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } footer: {
            "Canvas → Calendar → sidebar → Calendar Feed → copy URL."
        }
    }

    private var athleticsSection: some View {
        settingsBlock(title: "Athletics") {
            NavigationLink { AthleticsPickerView(services: services) } label: {
                brutalRow("Athletics teams", value: "\(AthleticSubscriptions.enabledIDs.count) on")
            }
        } footer: {
            "Pick which Suffield teams sync into the Athletics card."
        }
    }

    private var countdownSection: some View {
        settingsBlock(title: "Countdown") {
            NavigationLink { CountdownPickerView() } label: {
                brutalRow("Pick events", value: "\(CountdownSubscriptions.selectedIDs.count) on")
            }
        } footer: {
            "Count down to school events like Prom, Graduation, etc."
        }
    }

    private var apExamsSection: some View {
        settingsBlock(title: "AP Exams") {
            NavigationLink { APExamsPickerView() } label: {
                brutalRow("Pick your APs", value: "\(APExamSubscriptions.enabledIDs.count) on")
            }
        } footer: {
            "2026 exam schedule. Selected exams show up on the AP Exams card."
        }
    }

    private var eventsSection: some View {
        settingsBlock(title: "Events") {
            Button { showingCalendarImport = true } label: {
                brutalRow("Apple Calendars", value: "toggle")
            }
            .buttonStyle(.plain)
        } footer: {
            "Toggle which Apple Calendars show up in the Events tab."
        }
    }

    private var syncSection: some View {
        settingsBlock(title: "Sync") {
            VStack(spacing: 0) {
                syncRow(label: "Menu", date: menuSync); HairlineDivider()
                syncRow(label: "Events", date: eventsSync); HairlineDivider()
                syncRow(label: "Canvas", date: canvasSync); HairlineDivider()
                Button { Task { await forceRefresh() } } label: {
                    HStack {
                        Text("Force refresh")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                        Spacer()
                        if isRefreshing {
                            ProgressView().tint(AppColors.primary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(AppColors.secondary)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }
        }
    }

    private var permissionsSection: some View {
        settingsBlock(title: "Notifications") {
            HStack {
                Text("Permission")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Text(authLabel.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(0.6)
                    .foregroundStyle(authStatus == .authorized ? AppColors.primary : AppColors.secondary)
                if authStatus == .authorized {
                    Text("◆")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.primary)
                }
            }
            .padding(.vertical, 12)
            .overlay(HairlineDivider(), alignment: .bottom)
        }
    }

    private var aboutSection: some View {
        settingsBlock(title: "About") {
            HStack {
                Text("Version")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Text(versionString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.secondary)
            }
            .padding(.vertical, 12)
            .overlay(HairlineDivider(), alignment: .bottom)

            Text("SWISS KNIFE · \(versionString)")
                .font(.system(size: 9, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func settingsBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content,
        footer: (() -> String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.tertiary)
            HairlineDivider()
            content()
            if let footerText = footer?() {
                Text(footerText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
                    .padding(.top, 2)
            }
        }
    }

    private func brutalRow(_ label: String, value: String, good: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppColors.primary)
            Spacer()
            HStack(spacing: 4) {
                if good {
                    Text("◆")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.primary)
                }
                Text(value)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(0.6)
                    .foregroundStyle(good ? AppColors.primary : AppColors.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.tertiary)
                .padding(.leading, 4)
        }
        .padding(.vertical, 12)
        .overlay(HairlineDivider(), alignment: .bottom)
    }

    private func brutalField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 8).padding(.vertical, 8)
            .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
    }

    private func themeCell(_ theme: Theme) -> some View {
        let active = theme.id == themeManager.current.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Rectangle().fill(theme.primary).frame(width: 14, height: 14)
                Rectangle().fill(theme.accent).frame(width: 14, height: 14)
                ZStack {
                    Rectangle().fill(theme.surface).frame(width: 14, height: 14)
                    Rectangle().strokeBorder(theme.primary, lineWidth: 1).frame(width: 14, height: 14)
                }
            }
            Text(theme.name.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(0.8)
                .foregroundStyle(theme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
        .overlay(
            Rectangle()
                .strokeBorder(theme.primary, lineWidth: active ? 2.5 : 1.5)
        )
        .shadow(color: active ? AppColors.accent : .clear, radius: 0, x: 4, y: 4)
    }

    private func syncRow(label: String, date: Date?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppColors.primary)
            Spacer()
            Text(date.map(Self.syncFormatter.string) ?? "Never")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
        }
        .padding(.vertical, 10)
        .overlay(HairlineDivider(), alignment: .bottom)
    }

    private var authLabel: String {
        switch authStatus {
        case .authorized: return "Allowed"
        case .denied: return "Denied"
        case .notDetermined: return "Not asked"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private func readState() {
        let d = UserDefaults.standard
        menuSync = d.object(forKey: "lastSync.menu") as? Date
        eventsSync = d.object(forKey: "lastSync.events") as? Date
        canvasSync = d.object(forKey: "lastSync.canvas") as? Date
    }

    private func readAuth() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }

    private func forceRefresh() async {
        isRefreshing = true
        async let a: Void = runDining()
        async let b: Void = runEvents()
        async let c: Void = runCanvas()
        _ = await (a, b, c)
        readState()
        isRefreshing = false
    }

    private func runDining() async {
        _ = try? await services.dining.todaysMeal()
    }

    private func runEvents() async {
        _ = try? await services.events.upcomingEvents(forceRefresh: true)
    }

    private func runCanvas() async {
        try? await services.assignments.syncCanvas()
    }

    static let syncFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}
