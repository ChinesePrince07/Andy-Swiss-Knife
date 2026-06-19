import SwiftUI
import SwiftData
import UIKit

/// The app is portrait by default; the Badminton tab opts into landscape (the
/// side-on court setup) by widening this mask. `RootView` flips it on tab change.
final class AppDelegate: NSObject, UIApplicationDelegate {
    // Read by UIKit on the main thread and written only via AppOrientation.set
    // (@MainActor), so single-threaded access makes the unchecked global safe.
    nonisolated(unsafe) static var orientationMask: UIInterfaceOrientationMask = .portrait
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationMask
    }
}

@MainActor
enum AppOrientation {
    /// Permit `mask` and ask the active scene to re-evaluate — rotating back to a
    /// supported orientation if the current one is no longer allowed (e.g. leaving
    /// the Badminton tab while held landscape snaps back to portrait).
    static func set(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationMask = mask
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
}

@main
struct SwissKnifeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                .environment(PhotoRatioCache.shared)
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
    let badminton: BadmintonEngine

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
        self.badminton = BadmintonEngine()
        SnapshotStore.publishTodos(from: context)
        SnapshotStore.publishReminders(from: context)
        let importer = CalendarImporter(context: context)
        importer.syncEnabled()
        Task { await self.athletics.syncAllEnabled() }
        WidgetReloader.reloadAll()
    }

    static func seedSuffieldSchedule(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ScheduleClass>())) ?? []
        guard existing.isEmpty else { return }
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
    }
}

enum AppTab: String, Hashable, Codable, CaseIterable, Identifiable {
    case today, todos, classes, canvas, sports, files, blog, photos, badminton

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:     return "TODAY"
        case .todos:     return "TODOS"
        case .classes:   return "CLASS"
        case .canvas:    return "CANVAS"
        case .sports:    return "SPORTS"
        case .files:     return "FILES"
        case .blog:      return "BLOG"
        case .photos:    return "PICS"
        case .badminton: return "BADM"
        }
    }

    var icon: String {
        switch self {
        case .today:     return "house"
        case .todos:     return "list.bullet"
        case .classes:   return "clock"
        case .canvas:    return "book.closed"
        case .sports:    return "trophy"
        case .files:     return "folder"
        case .blog:      return "square.and.pencil"
        case .photos:    return "photo"
        case .badminton: return "figure.badminton"
        }
    }

    var filledIcon: String {
        switch self {
        case .today:     return "house.fill"
        case .todos:     return "list.bullet"
        case .classes:   return "clock.fill"
        case .canvas:    return "book.closed.fill"
        case .sports:    return "trophy.fill"
        case .files:     return "folder.fill"
        case .blog:      return "square.and.pencil"
        case .photos:    return "photo.fill"
        case .badminton: return "figure.badminton"
        }
    }

    static let allDefault: [AppTab] = [.today, .files]
}

struct RootView: View {
    let container: ModelContainer
    @State private var services: Services?
    @State private var selectedTab: AppTab = .today
    @State private var showOnboarding: Bool = !UserSettings.shared.hasCompletedOnboarding
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let services {
                VStack(spacing: 0) {
                    tabBody(services: services)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    BrutalTabBar(selected: $selectedTab)
                }
                .onAppear {
                    services.sweeper.sweep()
                    validateSelectedTab()
                    AppOrientation.set(selectedTab == .badminton ? .allButUpsideDown : .portrait)
                }
                .onChange(of: selectedTab) { _, tab in
                    AppOrientation.set(tab == .badminton ? .allButUpsideDown : .portrait)
                }
                .onChange(of: UserSettings.shared.enabledTabs) { _, _ in validateSelectedTab() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { services.sweeper.sweep() }
                }
                .onOpenURL { url in
                    DeepLinks.shared.handle(url)
                    selectedTab = .today
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(
                        onFinish: { showOnboarding = false },
                        modelContext: container.mainContext
                    )
                    .environment(ThemeManager.shared)
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
        case .blog:
            NavigationStack {
                BlogListView()
                    .withSettingsGear(services: services)
            }
        case .photos:
            NavigationStack {
                PhotoGalleryView()
                    .withSettingsGear(services: services)
            }
        case .badminton:
            NavigationStack {
                BadmintonView(services: services)
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
