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

struct RootView: View {
    let container: ModelContainer
    @State private var services: Services?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let services {
                NavigationStack {
                    TodayDashboardView(services: services)
                }
                .onAppear { services.sweeper.sweep() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { services.sweeper.sweep() }
                }
                .onOpenURL { url in
                    DeepLinks.shared.handle(url)
                }
            } else {
                Color.clear
                    .onAppear {
                        services = Services(context: container.mainContext)
                    }
            }
        }
    }
}
