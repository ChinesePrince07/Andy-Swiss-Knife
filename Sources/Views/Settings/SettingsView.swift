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

    var body: some View {
        @Bindable var userSettings = UserSettings.shared
        return List {
            Section("You") {
                TextField("Your name", text: $userSettings.displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
            }

            Section {
                NavigationLink {
                    ScheduleEditorView()
                } label: {
                    HStack {
                        Text("My classes")
                        Spacer()
                        Text("edit").foregroundStyle(AppColors.secondary)
                    }
                }
            } header: {
                Text("Schedule")
            } footer: {
                Text("Classes power the Next Class card and the Classes screen.")
            }

            Section {
                TextField("https://…instructure.com/feeds/calendars/user_….ics",
                          text: $userSettings.canvasFeedURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    .font(.system(size: 12, design: .monospaced))
            } header: {
                Text("Canvas feed URL")
            } footer: {
                Text("In Canvas: Calendar → right sidebar → Calendar Feed. Paste the .ics URL here. Pull-to-refresh the Canvas tab to sync.")
            }

            if Theme.all.count > 1 {
                Section("Theme") {
                    ForEach(Theme.all) { theme in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.select(theme)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                themeSwatch(theme)
                                Text(theme.name)
                                    .foregroundStyle(AppColors.primary)
                                Spacer()
                                if theme.id == themeManager.current.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                        }
                    }
                }
            }

            Section("Sync") {
                syncRow(label: "Menu", date: menuSync)
                syncRow(label: "Events", date: eventsSync)
                syncRow(label: "Canvas", date: canvasSync)
                Button {
                    Task { await forceRefresh() }
                } label: {
                    HStack {
                        Text("Force refresh")
                        Spacer()
                        if isRefreshing { ProgressView() }
                    }
                }
                .disabled(isRefreshing)
            }

            Section("Notifications") {
                HStack {
                    Text("Permission")
                    Spacer()
                    Text(authLabel).foregroundStyle(AppColors.secondary)
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(versionString).foregroundStyle(AppColors.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            readState()
            await readAuth()
        }
    }

    private func themeSwatch(_ theme: Theme) -> some View {
        HStack(spacing: 2) {
            Rectangle().fill(theme.background).frame(width: 10, height: 22)
            Rectangle().fill(theme.primary).frame(width: 10, height: 22)
            Rectangle().fill(theme.accent).frame(width: 10, height: 22)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius > 0 ? 4 : 0))
        .overlay(
            Rectangle().stroke(Color(white: 0.7), lineWidth: 0.5)
        )
    }

    private func syncRow(label: String, date: Date?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(date.map(Self.syncFormatter.string) ?? "Never")
                .foregroundStyle(AppColors.secondary)
        }
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
