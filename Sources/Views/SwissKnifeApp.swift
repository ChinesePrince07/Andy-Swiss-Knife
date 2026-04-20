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

    init(context: ModelContext) {
        let http = URLSessionHTTPClient()
        self.dining = DiningService(http: http, context: context)
        self.events = EventsService(http: http, context: context)
        self.assignments = AssignmentsSyncService(http: http, context: context)
        self.notifications = NotificationService()
        self.pomodoro = PomodoroTimer()
    }
}

struct RootView: View {
    let container: ModelContainer
    @State private var services: Services?

    var body: some View {
        Group {
            if let services {
                TabView {
                    NavigationStack {
                        TodayDashboardView(services: services)
                    }
                    .tabItem {
                        Label("Today", systemImage: "square.grid.2x2")
                    }

                    NavigationStack {
                        AssignmentsView(services: services)
                    }
                    .tabItem {
                        Label("Canvas", systemImage: "book")
                    }

                    NavigationStack {
                        PersonalCalendarView(services: services)
                    }
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
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
