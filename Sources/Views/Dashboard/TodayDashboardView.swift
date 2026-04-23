import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var weather: DailyWeather?
    @State private var showingAddSheet = false
    @State private var showingAddReminderSheet = false
    @State private var newTodoTitle: String = ""
    @FocusState private var addFieldFocused: Bool
    @State private var draggingCard: DashboardCard?
    @State private var dragOffset: CGSize = .zero
    @State private var cardFrames: [DashboardCard: CGRect] = [:]
    @State private var dragCardFrames: [DashboardCard: CGRect] = [:]
    @State private var lastSwappedCard: DashboardCard?
    @State private var workingActive: [DashboardCard] = []
    private let deepLinks = DeepLinks.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerWithSettings
                todoSection
                remindersSection
                glanceGrid
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ThemedBackground())
        .navigationBarHidden(true)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("\(UserSettings.shared.greeting(for: ctx.date)), \(UserSettings.shared.displayName)")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
                Text(Self.titleFormatter.string(from: ctx.date).uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.secondary)
                weatherLine
            }
        }
    }

    private var weatherLine: some View {
        HStack(spacing: 6) {
            if let w = weather {
                Image(systemName: w.symbolName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.secondary)
                Text("H \(Int(w.highC.rounded()))°  L \(Int(w.lowC.rounded()))°")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(1.1)
                    .foregroundStyle(AppColors.secondary)
            } else {
                Text("—")
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.tertiary)
            }
        }
    }

    private var headerWithSettings: some View {
        HStack(alignment: .top, spacing: 12) {
            header
            Spacer()
            NavigationLink {
                SettingsView(services: services)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
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
                HairlineDivider()
                ReorderableTodoList(items: openManualTodos, services: services)
                if !doneManualTodos.isEmpty {
                    doneSection
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.secondary)
                TextField("", text: $newTodoTitle, prompt: Text("Add task…").foregroundColor(AppColors.secondary))
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
                            .foregroundStyle(AppColors.secondary)
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
        // New undated todos get highest sortOrder so they appear at the top.
        let maxOrder = allTodos.compactMap(\.sortOrder).max() ?? 0
        let todo = Todo(title: trimmed, sortOrder: maxOrder + 1)
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

    private var openManualTodos: [Todo] {
        allTodos.filter { !$0.isDone }.sorted { lhs, rhs in
            let l = lhs.sortOrder ?? lhs.createdAt.timeIntervalSince1970
            let r = rhs.sortOrder ?? rhs.createdAt.timeIntervalSince1970
            return l > r
        }
    }

    private var doneManualTodos: [Todo] {
        allTodos.filter { $0.isDone }.sorted { $0.createdAt > $1.createdAt }
    }

    private var doneSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DONE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.tertiary)
                .padding(.top, 10)
            Rectangle().fill(AppColors.tertiary).frame(height: 1)
            ForEach(doneManualTodos) { todo in
                TodoRow(todo: todo, services: services)
                HairlineDivider()
            }
        }
    }

    private func clearDone() {
        for t in allTodos where t.isDone {
            services.notifications.cancel(for: t)
            modelContext.delete(t)
        }
        try? modelContext.save()
    }

    @State private var newReminderTitle: String = ""
    @FocusState private var reminderFieldFocused: Bool

    private var upcomingReminders: [PersonalEvent] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now)) ?? .now
        return personalEvents
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    private var reminderBuckets: [(DueBucket, [PersonalEvent])] {
        var map: [DueBucket: [PersonalEvent]] = [:]
        for e in upcomingReminders {
            let b = DueBucket.bucket(for: e.date)
            map[b, default: []].append(e)
        }
        return map.keys.sorted { $0.order < $1.order }.map { key in
            let items = (map[key] ?? []).sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                let l = lhs.sortOrder ?? 0
                let r = rhs.sortOrder ?? 0
                return l > r
            }
            return (key, items)
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                PersonalCalendarView(services: services)
            } label: {
                HStack {
                    SectionLabel(text: "Reminders")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.tertiary)
                }
            }
            .buttonStyle(.plain)

            if upcomingReminders.isEmpty {
                HairlineDivider()
                Text("No reminders yet.")
                    .font(AppType.body)
                    .foregroundStyle(AppColors.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(reminderBuckets.prefix(3), id: \.0) { bucket, items in
                    reminderBucketSection(bucket: bucket, items: items)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.secondary)
                TextField("", text: $newReminderTitle, prompt: Text("Add reminder…").foregroundColor(AppColors.secondary))
                    .font(AppType.body)
                    .foregroundStyle(AppColors.primary)
                    .focused($reminderFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { commitNewReminder() }
            }
            .padding(.vertical, 8)
        }
    }

    private func reminderBucketSection(bucket: DueBucket, items: [PersonalEvent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bucket.title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(1.3)
                    .foregroundStyle(bucket.isUrgent ? AppColors.accent : AppColors.primary)
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
            }
            Rectangle()
                .fill(bucket.isUrgent ? AppColors.accent : AppColors.primary)
                .frame(height: bucket.isUrgent ? 1.5 : 0.8)
            ForEach(items.prefix(4)) { e in
                ReminderRow(
                    event: e,
                    dateLabel: reminderRowLabel(e),
                    onOpen: {},
                    onDelete: { deleteReminder(e) },
                    onCommitTitle: { newVal in
                        let trimmed = newVal.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, trimmed != e.title else { return }
                        e.title = trimmed
                        try? modelContext.save()
                        SnapshotStore.publishReminders(from: modelContext)
                        WidgetReloader.reloadReminderWidgets()
                    }
                )
                .draggable(e.id.uuidString)
                .dropDestination(for: String.self) { dropped, _ in
                    reorderReminder(droppedIDs: dropped, target: e, within: Array(items.prefix(4)))
                }
                HairlineDivider()
            }
        }
    }

    private func reminderRowLabel(_ e: PersonalEvent) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(e.date) { return "Today" }
        if cal.isDateInTomorrow(e.date) { return "Tomorrow" }
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: e.date)
    }

    private func commitNewReminder() {
        let trimmed = newReminderTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let defaultDate = Calendar.current.startOfDay(for: .now)
        let event = PersonalEvent(title: trimmed, date: defaultDate, isAllDay: true)
        modelContext.insert(event)
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
        newReminderTitle = ""
        reminderFieldFocused = true
    }

    private func deleteReminder(_ e: PersonalEvent) {
        services.notifications.cancel(for: e)
        modelContext.delete(e)
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
    }

    private func reorderReminder(droppedIDs: [String], target: PersonalEvent, within bucket: [PersonalEvent]) -> Bool {
        guard let raw = droppedIDs.first, let id = UUID(uuidString: raw),
              let dropped = bucket.first(where: { $0.id == id }), dropped.id != target.id else { return false }
        var arr = bucket
        arr.removeAll { $0.id == dropped.id }
        guard let idx = arr.firstIndex(where: { $0.id == target.id }) else { return false }
        arr.insert(dropped, at: idx)
        let total = arr.count
        for (i, r) in arr.enumerated() {
            r.sortOrder = Double(total - i)
        }
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
        return true
    }


    private var glanceGrid: some View {
        let active = draggingCard == nil ? DashboardLayout.shared.active : workingActive
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(active, id: \.self) { card in
                gridCell(for: card)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: active)
        .coordinateSpace(name: "dashGrid")
        .buttonStyle(.plain)
        .onPreferenceChange(CardFramesKey.self) { frames in
            cardFrames = frames
        }
    }

    @ViewBuilder
    private func gridCell(for card: DashboardCard) -> some View {
        let isDragging = draggingCard == card
        let isOther = draggingCard != nil && !isDragging
        cardView(for: card)
            .scaleEffect(isDragging ? 1.12 : (isOther ? 0.96 : 1.0))
            .opacity(isOther ? 0.75 : 1.0)
            .rotationEffect(.degrees(isDragging ? 2.0 : 0))
            .shadow(
                color: isDragging ? AppColors.primary.opacity(0.45) : .clear,
                radius: isDragging ? 26 : 0,
                x: 0,
                y: isDragging ? 14 : 0
            )
            .offset(x: isDragging ? dragOffset.width : 0,
                    y: isDragging ? dragOffset.height : 0)
            .zIndex(isDragging ? 10 : 0)
            .animation(isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.72), value: draggingCard)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CardFramesKey.self,
                        value: [card: geo.frame(in: .named("dashGrid"))]
                    )
                }
            )
            .transaction { t in
                if isDragging { t.animation = nil }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .sequenced(before: DragGesture(coordinateSpace: .named("dashGrid")))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if draggingCard == nil {
                                draggingCard = card
                                workingActive = DashboardLayout.shared.active
                                dragCardFrames = cardFrames
                                lastSwappedCard = nil
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            if let drag {
                                dragOffset = drag.translation
                                handleSwap(draggedCard: card, location: drag.location)
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        if !workingActive.isEmpty {
                            DashboardLayout.shared.active = workingActive
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            draggingCard = nil
                            dragOffset = .zero
                        }
                        lastSwappedCard = nil
                        dragCardFrames = [:]
                        workingActive = []
                    }
            )
    }

    private func handleSwap(draggedCard: DashboardCard, location: CGPoint) {
        guard let hit = dragCardFrames.first(where: { entry in
            entry.key != draggedCard && entry.value.contains(location)
        }) else { return }
        if hit.key == lastSwappedCard { return }
        guard let fromIdx = workingActive.firstIndex(of: draggedCard),
              let toIdx = workingActive.firstIndex(of: hit.key),
              let oldDraggedFrame = dragCardFrames[draggedCard]
        else { return }
        let oldTargetFrame = hit.value

        dragCardFrames[draggedCard] = oldTargetFrame
        dragCardFrames[hit.key] = oldDraggedFrame

        workingActive.remove(at: fromIdx)
        workingActive.insert(draggedCard, at: toIdx)

        let delta = CGSize(
            width: oldDraggedFrame.midX - oldTargetFrame.midX,
            height: oldDraggedFrame.midY - oldTargetFrame.midY
        )
        dragOffset = CGSize(
            width: dragOffset.width + delta.width,
            height: dragOffset.height + delta.height
        )

        lastSwappedCard = hit.key
    }


    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        if draggingCard == card {
            rawCardContent(for: card)
        } else {
            NavigationLink {
                destination(for: card)
            } label: {
                rawCardContent(for: card)
            }
        }
    }

    @ViewBuilder
    private func rawCardContent(for card: DashboardCard) -> some View {
        switch card {
        case .nextClass:
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                GlanceCard(
                    label: "Next class",
                    primary: nextClassPrimary(now: ctx.date),
                    secondary: nextClassSecondary(now: ctx.date)
                )
            }
        case .canvas:
            GlanceCard(label: "Canvas", primary: canvasPrimary, secondary: canvasSecondary)
        case .meal:
            GlanceCard(label: mealCardLabel, primary: mealPrimary, secondary: mealSecondary, error: mealError)
        case .pomodoro:
            GlanceCard(label: "Pomodoro", primary: "Start", secondary: "25 min focus")
        case .events:
            GlanceCard(label: "Events", primary: nextEventPrimary, secondary: nextEventSecondary)
        case .athletics:
            GlanceCard(label: "Athletics", primary: athleticsPrimary, secondary: athleticsSecondary)
        case .apExams:
            GlanceCard(label: "AP Exams", primary: apExamsPrimary, secondary: apExamsSecondary)
        }
    }

    @ViewBuilder
    private func destination(for card: DashboardCard) -> some View {
        switch card {
        case .nextClass: ClassesView()
        case .canvas:    AssignmentsView(services: services)
        case .meal:      MealView(services: services)
        case .pomodoro:  PomodoroView(services: services)
        case .events:    EventsView(services: services)
        case .athletics: AthleticsView(services: services)
        case .apExams:   APExamsView()
        }
    }

    private var apExamsPrimary: String {
        guard let next = APExamSubscriptions.nextUpcoming() else {
            return APExamSubscriptions.enabledIDs.isEmpty ? "Tap to pick" : "All done"
        }
        return next.name
    }

    private var apExamsSecondary: String {
        guard let next = APExamSubscriptions.nextUpcoming() else {
            return APExamSubscriptions.enabledIDs.isEmpty ? "2026 schedule" : "—"
        }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: next.date)).day ?? 0
        let df = DateFormatter(); df.dateFormat = "MMM d"
        if days <= 0 { return "Today · \(next.session.label)" }
        if days == 1 { return "Tmrw · \(next.session.label)" }
        return "\(df.string(from: next.date)) · in \(days)d"
    }

    private var athleticsPrimary: String {
        guard let next = services.athletics.nextUpcoming() else { return "None soon" }
        return next.title
    }

    private var athleticsSecondary: String {
        guard let next = services.athletics.nextUpcoming() else {
            return AthleticSubscriptions.enabledIDs.isEmpty ? "Pick teams in settings" : "—"
        }
        let df = DateFormatter()
        df.dateFormat = Calendar.current.isDateInToday(next.start) ? "'Today' HH:mm" : "EEE MMM d"
        return df.string(from: next.start)
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
        async let wx: Void = refreshWeather()
        _ = await (meal, events, canvas, wx)
        isRefreshing = false
    }

    private func refreshWeather() async {
        weather = await services.weather.today()
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

struct CardFramesKey: PreferenceKey {
    static let defaultValue: [DashboardCard: CGRect] = [:]
    static func reduce(value: inout [DashboardCard: CGRect], nextValue: () -> [DashboardCard: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct CardDropDelegate: DropDelegate {
    let target: DashboardCard
    @Binding var dragging: DashboardCard?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        var active = DashboardLayout.shared.active
        guard let fromIdx = active.firstIndex(of: dragging),
              let toIdx = active.firstIndex(of: target)
        else { return }
        if fromIdx == toIdx { return }
        withAnimation(.snappy(duration: 0.22)) {
            active.move(fromOffsets: IndexSet(integer: fromIdx),
                        toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
            DashboardLayout.shared.active = active
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
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
