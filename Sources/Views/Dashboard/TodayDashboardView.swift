import SwiftUI
import SwiftData

struct TodayDashboardView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Todo> { $0.externalID == nil })
    private var allTodos: [Todo]
    @Query(filter: #Predicate<Todo> { $0.externalID != nil })
    private var canvasTodos: [Todo]
    @Query(sort: \PersonalEvent.date, order: .forward)
    private var personalEvents: [PersonalEvent]

    @State private var todaysMeal: Meal?
    @State private var nextEvent: Event?
    @State private var isRefreshing = false
    @State private var mealError: Bool = false
    @State private var showingAddSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                todoSection
                glanceGrid
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(services: services)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .refreshable {
            await refreshAll()
        }
        .task {
            await refreshAll()
        }
        .sheet(isPresented: $showingAddSheet) {
            TodoEditSheet(services: services, existing: nil)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.titleFormatter.string(from: .now))
                .font(AppType.displayTitle)
                .foregroundStyle(AppColors.primary)
            Text(counterLine)
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
        }
    }

    private var counterLine: String {
        let open = allTodos.filter { !$0.isDone }.count
        let done = allTodos.filter { $0.isDone }.count
        return "\(open) open · \(done) done"
    }

    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "To do")
            HairlineDivider()
            if allTodos.isEmpty {
                Text("No tasks yet.")
                    .font(AppType.body)
                    .foregroundStyle(AppColors.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(sortedTodos) { todo in
                    TodoRow(todo: todo, services: services)
                    HairlineDivider()
                }
            }
            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add task")
                }
                .font(AppType.body)
                .foregroundStyle(AppColors.primary)
                .padding(.vertical, 10)
            }
        }
    }

    private var sortedTodos: [Todo] {
        let open = allTodos.filter { !$0.isDone }.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(l), .some(r)): return l < r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.createdAt > rhs.createdAt
            }
        }
        let done = allTodos.filter { $0.isDone }.sorted { $0.createdAt > $1.createdAt }
        return open + done
    }

    private var glanceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            NavigationLink { ClassesView() } label: {
                GlanceCard(label: "Next class", primary: nextClassPrimary, secondary: nextClassSecondary)
            }
            NavigationLink { MealView(services: services) } label: {
                GlanceCard(label: "Lunch", primary: lunchPrimary, secondary: lunchSecondary, error: mealError)
            }
            NavigationLink { AssignmentsView(services: services) } label: {
                GlanceCard(label: "Canvas", primary: canvasPrimary, secondary: canvasSecondary)
            }
            NavigationLink { PersonalCalendarView(services: services) } label: {
                GlanceCard(label: "Reminders", primary: remindersPrimary, secondary: remindersSecondary)
            }
            NavigationLink { PomodoroView(services: services) } label: {
                GlanceCard(label: "Pomodoro", primary: "Start", secondary: "25 min focus")
            }
            NavigationLink { EventsView(services: services) } label: {
                GlanceCard(label: "Events", primary: nextEventPrimary, secondary: nextEventSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var canvasPrimary: String {
        let open = canvasTodos.filter { !$0.isDone }.count
        if open == 0 { return "All clear" }
        return "\(open) open"
    }

    private var canvasSecondary: String {
        let open = canvasTodos.filter { !$0.isDone }
        guard let next = open.compactMap(\.dueDate).sorted().first else { return "—" }
        return "Next \(Self.shortDue.string(from: next))"
    }

    private var remindersPrimary: String {
        let upcoming = personalEvents.filter { $0.date >= .now }
        if upcoming.isEmpty { return "None" }
        return upcoming.first?.title ?? "—"
    }

    private var remindersSecondary: String {
        let upcoming = personalEvents.filter { $0.date >= .now }
        guard let next = upcoming.first else { return "—" }
        return Self.shortDue.string(from: next.date)
    }

    static let shortDue: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()

    private var nextClassPrimary: String {
        guard let (next, _) = schedule.next(after: .now) else { return "None" }
        return next.name
    }

    private var nextClassSecondary: String {
        guard let (next, start) = schedule.next(after: .now) else { return "—" }
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        if Calendar.current.isDateInToday(start) {
            return "\(df.string(from: start))\(next.room.map { " · \($0)" } ?? "")"
        } else {
            let day = DateFormatter()
            day.dateFormat = "EEE"
            return "\(day.string(from: start)) \(df.string(from: start))"
        }
    }

    private var lunchPrimary: String {
        if mealError { return "Unavailable" }
        guard let meal = todaysMeal, !meal.lunch.isEmpty else { return "—" }
        return firstLine(meal.lunch)
    }

    private var lunchSecondary: String {
        if mealError { return "Tap for Safari" }
        guard let meal = todaysMeal, !meal.lunch.isEmpty else { return "No menu yet" }
        let lines = meal.lunch.split(separator: "\n").map(String.init)
        return lines.dropFirst().first ?? ""
    }

    private var nextEventPrimary: String {
        guard let next = nextEvent else { return "None" }
        return next.title
    }

    private var nextEventSecondary: String {
        guard let next = nextEvent else { return "—" }
        let df = DateFormatter()
        df.dateFormat = Calendar.current.isDateInToday(next.start) ? "h:mm a" : "EEE h:mm a"
        return df.string(from: next.start)
    }

    private func firstLine(_ s: String) -> String {
        String(s.split(separator: "\n").first ?? "—")
    }

    private func refreshAll() async {
        isRefreshing = true
        async let meal: Void = refreshMeal()
        async let events: Void = refreshEvents()
        async let canvas: Void = refreshCanvas()
        _ = await (meal, events, canvas)
        isRefreshing = false
    }

    private func refreshMeal() async {
        do {
            todaysMeal = try await services.dining.todaysMeal()
            mealError = false
        } catch {
            todaysMeal = services.dining.cachedTodaysMeal()
            mealError = todaysMeal == nil
        }
    }

    private func refreshEvents() async {
        do {
            let events = try await services.events.upcomingEvents()
            nextEvent = events.first
        } catch {
            // leave cached nextEvent as-is
        }
    }

    private func refreshCanvas() async {
        try? await services.assignments.syncCanvas()
    }

    static let titleFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df
    }()
}

struct GlanceCard: View {
    let label: String
    let primary: String
    let secondary: String
    var error: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
            Text(primary)
                .font(AppType.bodyMedium)
                .foregroundStyle(error ? AppColors.accent : AppColors.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(secondary)
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(
            Rectangle()
                .stroke(AppColors.hairline, lineWidth: 0.5)
        )
    }
}
