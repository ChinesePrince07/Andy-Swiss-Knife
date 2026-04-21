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
    @Query(sort: \ScheduleClass.sortKey) private var scheduleClasses: [ScheduleClass]

    @State private var todaysMeal: Meal?
    @State private var nextEvent: Event?
    @State private var isRefreshing = false
    @State private var mealError: Bool = false
    @State private var showingAddSheet = false
    @State private var showingAddReminderSheet = false
    private let deepLinks = DeepLinks.shared

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
        .background(ThemedBackground())
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
        .sheet(isPresented: $showingAddReminderSheet) {
            PersonalEventEditSheet(services: services, existing: nil)
        }
        .onChange(of: deepLinks.pendingAction) { _, action in
            guard let action else { return }
            switch action {
            case .addTodo:     showingAddSheet = true
            case .addReminder: showingAddReminderSheet = true
            }
            deepLinks.clear()
        }
        .onAppear {
            if let action = deepLinks.pendingAction {
                switch action {
                case .addTodo:     showingAddSheet = true
                case .addReminder: showingAddReminderSheet = true
                }
                deepLinks.clear()
            }
        }
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            VStack(alignment: .leading, spacing: 6) {
                Text("\(UserSettings.shared.greeting(for: ctx.date)), \(UserSettings.shared.displayName)")
                    .font(AppType.displayTitle)
                    .foregroundStyle(AppColors.primary)
                Text(Self.titleFormatter.string(from: ctx.date).uppercased())
                    .font(AppType.sectionLabel)
                    .kerning(1.2)
                    .foregroundStyle(AppColors.secondary)
                Text(counterLine)
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.secondary)
            }
        }
    }

    private var counterLine: String {
        let open = allTodos.filter { !$0.isDone }.count
        let done = allTodos.filter { $0.isDone }.count
        return "\(open) open · \(done) done"
    }

    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "To do")
                Spacer()
                if doneManualCount > 0 {
                    Button("Clear done") { clearDone() }
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
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

    private var doneManualCount: Int {
        allTodos.filter { $0.isDone }.count
    }

    private func clearDone() {
        for t in allTodos where t.isDone {
            services.notifications.cancel(for: t)
            modelContext.delete(t)
        }
        try? modelContext.save()
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
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    GlanceCard(
                        label: "Next class",
                        primary: nextClassPrimary(now: ctx.date),
                        secondary: nextClassSecondary(now: ctx.date)
                    )
                }
            }
            NavigationLink { PersonalCalendarView(services: services) } label: {
                GlanceCard(label: "Reminders", primary: remindersPrimary, secondary: remindersSecondary)
            }
            NavigationLink { AssignmentsView(services: services) } label: {
                GlanceCard(label: "Canvas", primary: canvasPrimary, secondary: canvasSecondary)
            }
            NavigationLink { MealView(services: services) } label: {
                GlanceCard(label: "Lunch", primary: lunchPrimary, secondary: lunchSecondary, error: mealError)
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

    private var visibleCanvasTodos: [Todo] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return canvasTodos.filter { todo in
            guard let due = todo.dueDate else { return true }
            return due >= startOfToday
        }
    }

    private var canvasPrimary: String {
        let counts = canvasDueCounts()
        if counts.today == 0 && counts.tomorrow == 0 { return "Nothing soon" }
        return "\(counts.today) today · \(counts.tomorrow) tmrw"
    }

    private var canvasSecondary: String {
        let open = visibleCanvasTodos.filter { !$0.isDone }.count
        return open == 0 ? "All clear" : "\(open) open total"
    }

    private func canvasDueCounts() -> (today: Int, tomorrow: Int) {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: .now)
        guard let startTmrw = cal.date(byAdding: .day, value: 1, to: startToday),
              let startDay2 = cal.date(byAdding: .day, value: 2, to: startToday)
        else { return (0, 0) }
        let open = visibleCanvasTodos.filter { !$0.isDone }
        let t = open.filter { ($0.dueDate.map { $0 >= startToday && $0 < startTmrw }) ?? false }.count
        let m = open.filter { ($0.dueDate.map { $0 >= startTmrw && $0 < startDay2 }) ?? false }.count
        return (t, m)
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

    private func nextClassPrimary(now: Date) -> String {
        guard let (next, _) = scheduleClasses.asClassPeriods().next(after: now) else { return "None" }
        return next.name
    }

    private func nextClassSecondary(now: Date) -> String {
        guard let (next, start) = scheduleClasses.asClassPeriods().next(after: now) else { return "—" }
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
        guard let meal = todaysMeal, !meal.lunch.isEmpty else { return "Loading…" }
        return meal.lunch
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: ", ,", with: ",")
    }

    private var lunchSecondary: String {
        if mealError { return "Tap for Safari" }
        guard let meal = todaysMeal, !meal.lunch.isEmpty else { return "—" }
        let age = Int(Date.now.timeIntervalSince(meal.fetchedAt) / 3600)
        return age >= 4 ? "as of \(age)h ago" : "Tap for full menu"
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

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        _ = themeManager.current  // ensure observation
        return VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(primary)
                .font(AppType.bodyMedium)
                .foregroundStyle(error ? AppColors.accent : AppColors.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(secondary)
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}
