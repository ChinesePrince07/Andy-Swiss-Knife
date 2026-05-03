import SwiftUI
import SwiftData

@main
struct SwissKnifeApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try AppModelContainer.make()
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .modelContainer(container)
                .environment(ThemeManager.shared)
                .tint(AppColors.primary)
                .preferredColorScheme(ThemeManager.shared.current.prefersDarkMode ? .dark : .light)
        }
    }
}

@MainActor
final class Services {
    let dining: DiningService
    let events: EventsService
    let assignments: AssignmentsSyncService
    let notifications: NotificationService
    let pomodoro: PomodoroTimer
    let sweeper: TodoSweeper
    let athletics: AthleticsService
    let weather: WeatherService

    init(context: ModelContext) {
        let http = URLSessionHTTPClient()
        self.dining = DiningService(http: http, context: context)
        self.events = EventsService(http: http, context: context)
        self.assignments = AssignmentsSyncService(http: http, context: context)
        self.notifications = NotificationService()
        self.pomodoro = PomodoroTimer()
        self.sweeper = TodoSweeper(context: context)
        self.athletics = AthleticsService(http: http, context: context)
        self.weather = WeatherService(http: http)
        Self.seedScheduleIfNeeded(context: context)
        SnapshotStore.publishTodos(from: context)
        SnapshotStore.publishReminders(from: context)
        let importer = CalendarImporter(context: context)
        importer.syncEnabled()
        Task { await self.athletics.syncAllEnabled() }
        WidgetReloader.reloadAll()
    }

    static func seedScheduleIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ScheduleClass>())) ?? []
        let didSeedKey = "schedule.didSeedDefaults"
        let didSeed = UserDefaults.standard.bool(forKey: didSeedKey)
        guard existing.isEmpty, !didSeed else { return }
        for p in defaultSchedule {
            context.insert(ScheduleClass(
                name: p.name,
                room: p.room,
                teacher: p.teacher,
                daysOfWeek: p.daysOfWeek,
                startHour: p.startTime.hour ?? 0,
                startMinute: p.startTime.minute ?? 0,
                endHour: p.endTime.hour ?? 0,
                endMinute: p.endTime.minute ?? 0,
                kindRaw: p.kind == .lunch ? "lunch" : "academic"
            ))
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: didSeedKey)
    }
}

enum AppTab: String, Hashable, Codable, CaseIterable, Identifiable {
    case today, todos, classes, canvas, sports, files

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:   return "TODAY"
        case .todos:   return "TODOS"
        case .classes: return "CLASS"
        case .canvas:  return "CANVAS"
        case .sports:  return "SPORTS"
        case .files:   return "FILES"
        }
    }

    var icon: String {
        switch self {
        case .today:   return "house"
        case .todos:   return "list.bullet"
        case .classes: return "clock"
        case .canvas:  return "book.closed"
        case .sports:  return "trophy"
        case .files:   return "folder"
        }
    }

    var filledIcon: String {
        switch self {
        case .today:   return "house.fill"
        case .todos:   return "list.bullet"
        case .classes: return "clock.fill"
        case .canvas:  return "book.closed.fill"
        case .sports:  return "trophy.fill"
        case .files:   return "folder.fill"
        }
    }

    static let allDefault: [AppTab] = [.today, .files]
}

struct RootView: View {
    let container: ModelContainer
    @State private var services: Services?
    @State private var selectedTab: AppTab = .today
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let services {
                tabBody(services: services)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        BrutalTabBar(selected: $selectedTab)
                    }
                    .onAppear {
                        services.sweeper.sweep()
                        validateSelectedTab()
                    }
                    .onChange(of: UserSettings.shared.enabledTabs) { _, _ in validateSelectedTab() }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active { services.sweeper.sweep() }
                    }
                    .onOpenURL { url in
                        DeepLinks.shared.handle(url)
                        selectedTab = .today
                    }
            } else {
                Color.clear
                    .onAppear {
                        services = Services(context: container.mainContext)
                    }
            }
        }
    }

    private func validateSelectedTab() {
        let enabled = UserSettings.shared.enabledTabs
        if !enabled.contains(selectedTab) {
            selectedTab = enabled.first ?? .today
        }
    }

    @ViewBuilder
    private func tabBody(services: Services) -> some View {
        switch selectedTab {
        case .today:
            NavigationStack {
                TodayDashboardView(services: services)
            }
        case .todos:
            NavigationStack {
                TodosTabView(services: services)
                    .withSettingsGear(services: services)
            }
        case .classes:
            NavigationStack {
                ClassesView()
                    .withSettingsGear(services: services)
            }
        case .canvas:
            NavigationStack {
                AssignmentsView(services: services)
                    .withSettingsGear(services: services)
            }
        case .sports:
            NavigationStack {
                AthleticsView(services: services)
                    .withSettingsGear(services: services)
            }
        case .files:
            NavigationStack {
                FilesView()
                    .withSettingsGear(services: services)
            }
        }
    }
}

// MARK: - Settings Gear Toolbar

private struct SettingsGearModifier: ViewModifier {
    let services: Services
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(services: services)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
    }
}

extension View {
    func withSettingsGear(services: Services) -> some View {
        modifier(SettingsGearModifier(services: services))
    }
}

struct BrutalTabBar: View {
    @Binding var selected: AppTab
    @Environment(ThemeManager.self) private var themeManager
    private var tabs: [AppTab] { UserSettings.shared.enabledTabs }

    var body: some View {
        _ = themeManager.current
        return VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.primary)
                .frame(height: 2)
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabItem(tab)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .background(AppColors.background.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func tabItem(_ tab: AppTab) -> some View {
        let active = selected == tab
        Button { selected = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: active ? tab.filledIcon : tab.icon)
                    .font(.system(size: 18, weight: active ? .bold : .regular))
                    .foregroundStyle(active ? AppColors.primary : AppColors.tertiary)
                Text(tab.label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(active ? AppColors.primary : AppColors.tertiary)
                Rectangle()
                    .fill(active ? AppColors.primary : Color.clear)
                    .frame(width: 16, height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
