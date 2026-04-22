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
                NavigationLink {
                    DashboardLayoutEditor()
                } label: {
                    HStack {
                        Text("Customize dashboard")
                        Spacer()
                        Text("arrange").foregroundStyle(AppColors.secondary)
                    }
                }
            } header: {
                Text("Layout")
            } footer: {
                Text("Reorder cards, hide ones you don't use, and re-activate hidden cards like Pomodoro or Athletics.")
            }

            Section {
                NavigationLink {
                    AthleticsPickerView(services: services)
                } label: {
                    HStack {
                        Text("Athletics teams")
                        Spacer()
                        Text("\(AthleticSubscriptions.enabledIDs.count) on")
                            .foregroundStyle(AppColors.secondary)
                    }
                }
            } header: {
                Text("Athletics")
            } footer: {
                Text("Pick which Suffield teams' schedules sync into the Athletics card.")
            }

            Section {
                Button {
                    showingCalendarImport = true
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Apple Calendars")
                        Spacer()
                    }
                }
            } header: {
                Text("Events")
            } footer: {
                Text("Toggle which Apple Calendars show up in the Events tab. Events sync automatically.")
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
                    HStack(spacing: 14) {
                        ForEach(Theme.all) { theme in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.select(theme)
                                }
                            } label: {
                                themeDot(theme)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
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
        .sheet(isPresented: $showingCalendarImport) {
            CalendarImportView()
        }
    }

    private func themeDot(_ theme: Theme) -> some View {
        let selected = theme.id == themeManager.current.id
        return ZStack {
            Circle()
                .fill(theme.background)
            Circle()
                .trim(from: 0.5, to: 1.0)
                .fill(theme.accent)
            Circle()
                .strokeBorder(theme.primary, lineWidth: selected ? 2 : 0.5)
        }
        .frame(width: 30, height: 30)
        .overlay(
            Circle()
                .strokeBorder(AppColors.accent, lineWidth: selected ? 2 : 0)
                .frame(width: 36, height: 36)
        )
        .padding(3)
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
