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

enum AppTab: Hashable {
    case today, todos, classes, canvas, sports
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
                    .onAppear { services.sweeper.sweep() }
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
            }
        case .classes:
            NavigationStack {
                ClassesView()
            }
        case .canvas:
            NavigationStack {
                AssignmentsView(services: services)
            }
        case .sports:
            NavigationStack {
                AthleticsView(services: services)
            }
        }
    }
}

struct BrutalTabBar: View {
    @Binding var selected: AppTab
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current
        return VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.primary)
                .frame(height: 2)
            HStack(spacing: 0) {
                tabItem(.today,   label: "TODAY",  icon: "house",        filledIcon: "house.fill")
                tabItem(.todos,   label: "TODOS",  icon: "list.bullet",  filledIcon: "list.bullet")
                tabItem(.classes, label: "CLASS",  icon: "clock",        filledIcon: "clock.fill")
                tabItem(.canvas,  label: "CANVAS", icon: "book.closed",  filledIcon: "book.closed.fill")
                tabItem(.sports,  label: "SPORTS", icon: "trophy",       filledIcon: "trophy.fill")
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .background(AppColors.background.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func tabItem(_ tab: AppTab, label: String, icon: String, filledIcon: String) -> some View {
        let active = selected == tab
        Button { selected = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: active ? filledIcon : icon)
                    .font(.system(size: 18, weight: active ? .bold : .regular))
                    .foregroundStyle(active ? AppColors.primary : AppColors.tertiary)
                Text(label)
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
