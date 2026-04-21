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
    @State private var newTodoTitle: String = ""
    @FocusState private var addFieldFocused: Bool
    @State private var isEditingGrid = false
    @State private var wigglePhase = false
    @State private var draggingCard: DashboardCard?
    private let deepLinks = DeepLinks.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                todoSection
                glanceGrid
            }
            .padding(.horizontal, 16)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "To do")
                Spacer()
                if doneManualCount > 0 {
                    Button("Clear done") { clearDone() }
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
            if allTodos.isEmpty {
                HairlineDivider()
                Text("No tasks yet.")
                    .font(AppType.body)
                    .foregroundStyle(AppColors.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(todoBuckets, id: \.0) { bucket, todos in
                    DueGroupSection(
                        title: bucket.title,
                        subtitle: bucket.subtitle,
                        isUrgent: bucket.isUrgent,
                        items: todos,
                        services: services
                    )
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.tertiary)
                TextField("Add task…", text: $newTodoTitle)
                    .font(AppType.body)
                    .foregroundStyle(AppColors.primary)
                    .focused($addFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { commitNewTodo() }
                if !newTodoTitle.isEmpty {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func commitNewTodo() {
        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let todo = Todo(title: trimmed)
        modelContext.insert(todo)
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
        newTodoTitle = ""
        addFieldFocused = true
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

    private var todoBuckets: [(DueBucket, [Todo])] {
        let open = allTodos.filter { !$0.isDone }
        var groups = DueBucket.group(todos: open)
        let done = allTodos.filter { $0.isDone }
        if !done.isEmpty {
            groups.append((DueBucket.done, done.sorted { $0.createdAt > $1.createdAt }))
        }
        return groups
    }

    private var glanceGrid: some View {
        let layout = DashboardLayout.shared
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(layout.order, id: \.self) { card in
                wiggleWrapper(for: card) {
                    cardView(for: card)
                }
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.4) {
            enterEditMode()
        }
        .overlay(alignment: .topTrailing) {
            if isEditingGrid {
                Button("Done") {
                    exitEditMode()
                }
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.accent, lineWidth: 2))
                .offset(x: -4, y: -14)
            }
        }
    }

    @ViewBuilder
    private func wiggleWrapper<Content: View>(for card: DashboardCard, @ViewBuilder content: () -> Content) -> some View {
        let wrapped = content()
            .rotationEffect(
                .degrees(isEditingGrid ? (wiggleOffset(for: card) ? 1.2 : -1.2) : 0)
            )
            .scaleEffect(draggingCard == card ? 1.05 : 1.0)
            .opacity(draggingCard == card ? 0.6 : 1.0)
            .allowsHitTesting(!isEditingGrid || draggingCard == nil)

        if isEditingGrid {
            wrapped
                .draggable(card.rawValue) {
                    content()
                        .frame(maxWidth: 170)
                        .onAppear { draggingCard = card }
                        .onDisappear { draggingCard = nil }
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let raw = items.first,
                          let from = DashboardCard(rawValue: raw),
                          let fromIdx = DashboardLayout.shared.order.firstIndex(of: from),
                          let toIdx = DashboardLayout.shared.order.firstIndex(of: card)
                    else { return false }
                    if fromIdx == toIdx { return false }
                    var order = DashboardLayout.shared.order
                    order.remove(at: fromIdx)
                    let adjusted = toIdx > fromIdx ? toIdx - 1 : toIdx
                    order.insert(from, at: adjusted)
                    withAnimation(.snappy(duration: 0.25)) {
                        DashboardLayout.shared.order = order
                    }
                    return true
                }
        } else {
            wrapped
        }
    }

    private func wiggleOffset(for card: DashboardCard) -> Bool {
        let idx = DashboardLayout.shared.order.firstIndex(of: card) ?? 0
        return idx.isMultiple(of: 2) ? wigglePhase : !wigglePhase
    }

    private func enterEditMode() {
        guard !isEditingGrid else { return }
        isEditingGrid = true
        withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
            wigglePhase.toggle()
        }
    }

    private func exitEditMode() {
        withAnimation(.easeInOut(duration: 0.12)) {
            wigglePhase = false
        }
        isEditingGrid = false
    }

    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        switch card {
        case .nextClass:
            NavigationLink { ClassesView() } label: {
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    GlanceCard(
                        label: "Next class",
                        primary: nextClassPrimary(now: ctx.date),
                        secondary: nextClassSecondary(now: ctx.date)
                    )
                }
            }
        case .reminders:
            NavigationLink { PersonalCalendarView(services: services) } label: {
                GlanceCard(label: "Reminders", primary: remindersPrimary, secondary: remindersSecondary)
            }
        case .canvas:
            NavigationLink { AssignmentsView(services: services) } label: {
                GlanceCard(label: "Canvas", primary: canvasPrimary, secondary: canvasSecondary)
            }
        case .meal:
            NavigationLink { MealView(services: services) } label: {
                GlanceCard(label: mealCardLabel, primary: mealPrimary, secondary: mealSecondary, error: mealError)
            }
        case .pomodoro:
            NavigationLink { PomodoroView(services: services) } label: {
                GlanceCard(label: "Pomodoro", primary: "Start", secondary: "25 min focus")
            }
        case .events:
            NavigationLink { EventsView(services: services) } label: {
                GlanceCard(label: "Events", primary: nextEventPrimary, secondary: nextEventSecondary)
            }
        }
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

    private var activeMealSlot: MealSlot {
        let hour = Calendar.current.component(.hour, from: .now)
        // Lunch windows roughly end 1pm, dinner opens 5:30pm. Show dinner
        // once lunch is past so the card rolls over automatically.
        return hour >= 13 ? .dinner : .lunch
    }

    private var mealCardLabel: String {
        activeMealSlot == .dinner ? "Dinner" : "Lunch"
    }

    private var mealPrimary: String {
        if mealError { return "Unavailable" }
        guard let meal = todaysMeal else { return "Loading…" }
        let text = activeMealSlot == .dinner ? meal.dinner : meal.lunch
        guard !text.isEmpty else { return "—" }
        return text
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: ", ,", with: ",")
    }

    private var mealSecondary: String {
        if mealError { return "Tap for Safari" }
        guard let meal = todaysMeal else { return "—" }
        let age = Int(Date.now.timeIntervalSince(meal.fetchedAt) / 3600)
        return age >= 4 ? "as of \(age)h ago" : "Tap for full menu"
    }

    private enum MealSlot { case lunch, dinner }

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
        return VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .kerning(1.1)
                .foregroundStyle(AppColors.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(primary)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(error ? AppColors.accent : AppColors.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(secondary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .overlay(
            Rectangle()
                .strokeBorder(AppColors.primary, lineWidth: 1.5)
        )
    }
}
