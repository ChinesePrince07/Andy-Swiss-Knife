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
                .preferredColorScheme(.light)
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

    init(context: ModelContext) {
        let http = URLSessionHTTPClient()
        self.dining = DiningService(http: http, context: context)
        self.events = EventsService(http: http, context: context)
        self.assignments = AssignmentsSyncService(http: http, context: context)
        self.notifications = NotificationService()
        self.pomodoro = PomodoroTimer()
        self.sweeper = TodoSweeper(context: context)
    }
}

struct RootView: View {
    let container: ModelContainer
    @State private var services: Services?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let services {
                TabView {
                    NavigationStack {
                        TodayDashboardView(services: services)
                    }
                    .tabItem { Label("Classic", systemImage: "square.grid.2x2") }

                    NavigationStack {
                        TodayV2View(services: services)
                    }
                    .tabItem { Label("Today v2", systemImage: "sparkles") }
                }
                .onAppear { services.sweeper.sweep() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { services.sweeper.sweep() }
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
