import SwiftUI
import SwiftData

/// Prototype "Today v2" layout based on the provided mockup.
/// Uses local palette (not the theme system) to match the design exactly.
struct TodayV2View: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Todo> { $0.externalID == nil })
    private var manualTodos: [Todo]
    @Query(filter: #Predicate<Todo> { $0.externalID != nil })
    private var canvasTodos: [Todo]
    @Query(sort: \ScheduleClass.sortKey) private var scheduleClasses: [ScheduleClass]

    @State private var todaysMeal: Meal?
    @State private var filter: Filter = .today
    @State private var showingAdd = false

    enum Filter: Hashable { case today, week, all }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                greetingHeader
                todosHeader
                progressBar
                filterSegmented
                todosList
                quickAddPill
                pairedGrid
                canvasPreview
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .background(V2.backgroundSecondary.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await refreshMeal()
            try? await services.assignments.syncCanvas()
        }
        .refreshable {
            await refreshMeal()
            try? await services.assignments.syncCanvas()
        }
        .sheet(isPresented: $showingAdd) {
            TodoEditSheet(services: services, existing: nil)
        }
    }

    // MARK: - Sections

    private var greetingHeader: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let name = UserSettings.shared.displayName
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.headerDate.string(from: ctx.date).uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .kerning(0.5)
                        .foregroundStyle(V2.accent)
                    (Text("\(UserSettings.shared.greeting(for: ctx.date)),\n")
                        .font(.system(size: 24, weight: .medium))
                     + Text(name).font(.system(size: 24, weight: .medium)))
                        .foregroundStyle(V2.textPrimary)
                        .lineSpacing(2)
                }
                Spacer()
                ZStack {
                    Circle().fill(V2.accentBackground).frame(width: 34, height: 34)
                    Text(initials(of: name))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(V2.accent)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    private func initials(of name: String) -> String {
        let parts = name.split(separator: " ")
        let chars = parts.compactMap { $0.first.map(String.init) }
        return chars.prefix(2).joined().uppercased()
    }

    private var todosHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Todos").font(.system(size: 18, weight: .medium))
                .foregroundStyle(V2.textPrimary)
            Spacer()
            Text("\(doneCount) of \(totalCount) done")
                .font(.system(size: 12))
                .foregroundStyle(V2.textSecondary)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(V2.backgroundTertiary).frame(height: 3)
                Capsule().fill(V2.accent)
                    .frame(width: max(0, geo.size.width * progressRatio), height: 3)
            }
        }
        .frame(height: 3)
    }

    private var filterSegmented: some View {
        HStack(spacing: 2) {
            segment(.today, label: "Today · \(countFor(.today))")
            segment(.week, label: "Week · \(countFor(.week))")
            segment(.all, label: "All · \(countFor(.all))")
        }
        .padding(2)
        .background(V2.backgroundTertiary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func segment(_ f: Filter, label: String) -> some View {
        Button { filter = f } label: {
            Text(label)
                .font(.system(size: 12, weight: filter == f ? .medium : .regular))
                .foregroundStyle(filter == f ? V2.textPrimary : V2.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    filter == f
                    ? AnyView(V2.backgroundPrimary.clipShape(RoundedRectangle(cornerRadius: 6)))
                    : AnyView(Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var todosList: some View {
        VStack(spacing: 0) {
            ForEach(filteredTodos) { todo in
                TodoV2Row(todo: todo, services: services)
                if todo.id != filteredTodos.last?.id {
                    Rectangle()
                        .fill(V2.borderTertiary)
                        .frame(height: 0.5)
                        .padding(.leading, 42)
                }
            }
            if filteredTodos.isEmpty {
                Text("Nothing \(filter == .today ? "today" : filter == .week ? "this week" : "yet").")
                    .font(.system(size: 13))
                    .foregroundStyle(V2.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(V2.backgroundPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(V2.borderTertiary, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var quickAddPill: some View {
        Button { showingAdd = true } label: {
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(V2.textTertiary, style: StrokeStyle(lineWidth: 1.2, dash: [1.5, 1.5]))
                    .frame(width: 14, height: 14)
                    .overlay(Text("+").font(.system(size: 10)).foregroundStyle(V2.textTertiary))
                Text("Quick add, # tag, @ time")
                    .font(.system(size: 12))
                    .foregroundStyle(V2.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(V2.backgroundTertiary, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var pairedGrid: some View {
        HStack(spacing: 10) {
            nextClassCard
            lunchCard
        }
        .padding(.top, 6)
    }

    private var nextClassCard: some View {
        NavigationLink { ClassesView() } label: {
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                nextClassContent(now: ctx.date)
            }
        }
        .buttonStyle(.plain)
    }

    private func nextClassContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("NEXT CLASS")
                    .font(.system(size: 10, weight: .medium))
                    .kerning(0.5)
                    .foregroundStyle(V2.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(V2.accent)
            }
            .padding(.bottom, 8)

            if let (cls, start) = scheduleClasses.asClassPeriods().next(after: now) {
                    Text(cls.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(V2.textPrimary)
                        .lineLimit(1)
                    Text(cls.room.map { "\(cls.teacher ?? "—") · \($0)" } ?? (cls.teacher ?? "—"))
                        .font(.system(size: 11))
                        .foregroundStyle(V2.accent)
                        .padding(.bottom, 8)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Self.hhmm.string(from: start))
                            .font(.system(size: 20, weight: .medium, design: .default))
                            .foregroundStyle(V2.textPrimary)
                            .monospacedDigit()
                        if let end = cls.endDate(on: start) {
                            Text("to \(Self.hhmm.string(from: end))")
                                .font(.system(size: 10))
                                .foregroundStyle(V2.accent)
                        }
                    }
                    Rectangle().fill(V2.accentBorder).frame(height: 0.5).padding(.vertical, 6)
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(V2.accent)
                        Text(minutesUntil(start))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(V2.accent)
                    }
                } else {
                    Text("No more today")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(V2.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(V2.accentBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(V2.accentBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var lunchCard: some View {
        NavigationLink { MealView(services: services) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("TODAY'S LUNCH")
                        .font(.system(size: 10, weight: .medium))
                        .kerning(0.5)
                        .foregroundStyle(V2.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(V2.textTertiary)
                }
                .padding(.bottom, 8)

                Text(lunchHeadline)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(V2.textPrimary)
                    .lineLimit(1)
                Text("Dining Hall")
                    .font(.system(size: 11))
                    .foregroundStyle(V2.textSecondary)
                    .padding(.bottom, 9)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(lunchItems.prefix(4).enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 6) {
                            Circle().fill(dotColor(for: idx)).frame(width: 4, height: 4)
                            Text(item)
                                .font(.system(size: 11.5, weight: idx == 0 ? .medium : .regular))
                                .foregroundStyle(idx == 0 ? V2.textPrimary : V2.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(V2.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(V2.borderTertiary, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var canvasPreview: some View {
        NavigationLink { AssignmentsView(services: services) } label: {
            VStack(spacing: 9) {
                HStack {
                    Text("CANVAS")
                        .font(.system(size: 10, weight: .medium))
                        .kerning(0.5)
                        .foregroundStyle(V2.textSecondary)
                    Spacer()
                    Text("\(visibleCanvasOpen.count) due")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(V2.success)
                        .padding(.horizontal, 7).padding(.vertical, 1.5)
                        .background(V2.successBackground, in: Capsule())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(V2.textTertiary)
                }
                ForEach(visibleCanvasOpen.prefix(3)) { item in
                    canvasRow(item)
                }
                if visibleCanvasOpen.isEmpty {
                    Text("All clear").font(.system(size: 12)).foregroundStyle(V2.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(V2.backgroundPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(V2.borderTertiary, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func canvasRow(_ item: Todo) -> some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(dueStripColor(for: item))
                .frame(width: 2, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(shortTitle(item.title))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(V2.textPrimary)
                    .lineLimit(1)
                Text(courseName(from: item.title))
                    .font(.system(size: 10))
                    .foregroundStyle(V2.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(dueLabel(for: item))
                .font(.system(size: 10, weight: dueIsUrgent(item) ? .medium : .regular))
                .foregroundStyle(dueIsUrgent(item) ? V2.danger : V2.textSecondary)
        }
    }

    // MARK: - Data helpers

    private var filteredTodos: [Todo] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfToday)!

        let filtered: [Todo]
        switch filter {
        case .today:
            filtered = manualTodos.filter {
                if let d = $0.dueDate {
                    return d < endOfToday
                } else {
                    return !$0.isDone
                }
            }
        case .week:
            filtered = manualTodos.filter {
                guard let d = $0.dueDate else { return false }
                return d >= startOfToday && d < endOfWeek
            }
        case .all:
            filtered = manualTodos
        }
        return filtered.sorted {
            if $0.isDone != $1.isDone { return !$0.isDone && $1.isDone }
            switch ($0.dueDate, $1.dueDate) {
            case let (.some(a), .some(b)): return a < b
            case (.some, .none): return true
            case (.none, .some): return false
            default: return $0.createdAt > $1.createdAt
            }
        }
    }

    private var totalCount: Int { filteredTodos.count }
    private var doneCount: Int { filteredTodos.filter(\.isDone).count }
    private var progressRatio: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    private func countFor(_ f: Filter) -> Int {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfToday)!
        switch f {
        case .today: return manualTodos.filter {
            if let d = $0.dueDate { return d < endOfToday } else { return !$0.isDone }
        }.count
        case .week: return manualTodos.filter {
            guard let d = $0.dueDate else { return false }
            return d >= startOfToday && d < endOfWeek
        }.count
        case .all: return manualTodos.count
        }
    }

    private var visibleCanvasOpen: [Todo] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return canvasTodos
            .filter { !$0.isDone && ($0.dueDate.map { $0 >= startOfToday } ?? true) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var lunchHeadline: String {
        guard let meal = todaysMeal, !meal.lunch.isEmpty else { return "Menu loading" }
        return firstItem(meal.lunch)
    }

    private var lunchItems: [String] {
        guard let meal = todaysMeal else { return [] }
        let source = !meal.lunch.isEmpty ? meal.lunch : meal.dinner
        return source
            .replacingOccurrences(of: "\n", with: ", ")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private func firstItem(_ s: String) -> String {
        let collapsed = s.replacingOccurrences(of: "\n", with: ", ")
        return String(collapsed.split(separator: ",").first ?? "—")
            .trimmingCharacters(in: .whitespaces)
    }

    private func minutesUntil(_ date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSinceNow / 60))
        if minutes == 0 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        let hours = minutes / 60
        return "in \(hours) hr"
    }

    private func dueLabel(for todo: Todo) -> String {
        guard let due = todo.dueDate else { return "—" }
        let cal = Calendar.current
        if cal.isDateInToday(due) { return "today" }
        if cal.isDateInTomorrow(due) { return "tmrw" }
        let df = DateFormatter(); df.dateFormat = "EEE"
        return df.string(from: due)
    }

    private func dueIsUrgent(_ todo: Todo) -> Bool {
        guard let due = todo.dueDate else { return false }
        return Calendar.current.isDateInToday(due) || due < .now
    }

    private func dueStripColor(for todo: Todo) -> Color {
        if dueIsUrgent(todo) { return V2.danger }
        return V2.accent
    }

    private func shortTitle(_ s: String) -> String {
        if let idx = s.range(of: "[")?.lowerBound {
            return String(s[..<idx]).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    private func courseName(from s: String) -> String {
        guard let l = s.range(of: "["), let r = s.range(of: "]") else { return "" }
        return String(s[l.upperBound..<r.lowerBound])
    }

    private func dotColor(for idx: Int) -> Color {
        [V2.accent, V2.success, V2.success, V2.pink][idx % 4]
    }

    private func refreshMeal() async {
        todaysMeal = try? await services.dining.todaysMeal()
    }

    // MARK: - Formatters

    static let headerDate: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "EEEE, MMMM d"; return df
    }()
    static let hhmm: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "HH:mm"; return df
    }()
}

// MARK: - Todo row (v2)

private struct TodoV2Row: View {
    @Bindable var todo: Todo
    let services: Services
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false

    var body: some View {
        Button { showingEdit = true } label: {
            HStack(alignment: .top, spacing: 11) {
                Button { toggle() } label: {
                    Circle()
                        .strokeBorder(todo.isDone ? V2.accent : V2.textTertiary, lineWidth: 1.5)
                        .background(
                            Circle()
                                .fill(todo.isDone ? V2.accentBackground : Color.clear)
                        )
                        .overlay(
                            todo.isDone
                            ? Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(V2.accent)
                            : nil
                        )
                        .frame(width: 19, height: 19)
                        .padding(.top, 1)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.system(size: 14, weight: todo.isDone ? .regular : .medium))
                        .foregroundStyle(todo.isDone ? V2.textSecondary : V2.textPrimary)
                        .strikethrough(todo.isDone)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 5) {
                        if let chip = dueChip {
                            Text(chip.text)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(chip.fg)
                                .padding(.horizontal, 7).padding(.vertical, 1.5)
                                .background(chip.bg, in: Capsule())
                        }
                        if let notes = todo.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 10))
                                .foregroundStyle(V2.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(V2.textTertiary)
                    .padding(.top, 4)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if todo.source == .manual {
                Button(role: .destructive) { delete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            TodoEditSheet(services: services, existing: todo)
        }
    }

    private struct Chip { let text: String; let fg: Color; let bg: Color }

    private var dueChip: Chip? {
        guard let due = todo.dueDate, !todo.isDone else { return nil }
        let cal = Calendar.current
        if due < .now {
            return Chip(text: "overdue", fg: V2.danger, bg: V2.dangerBackground)
        }
        if cal.isDateInToday(due) {
            let df = DateFormatter(); df.dateFormat = "HH:mm"
            return Chip(text: "due \(df.string(from: due))", fg: V2.danger, bg: V2.dangerBackground)
        }
        if cal.isDateInTomorrow(due) {
            return Chip(text: "tmrw", fg: V2.accent, bg: V2.accentBackground)
        }
        let df = DateFormatter(); df.dateFormat = "EEE"
        return Chip(text: df.string(from: due), fg: V2.textSecondary, bg: V2.backgroundTertiary)
    }

    private func toggle() {
        todo.isDone.toggle()
        todo.completedAt = todo.isDone ? .now : nil
        if todo.isDone {
            services.notifications.cancel(for: todo)
        } else if let d = todo.dueDate, d > .now {
            Task { await services.notifications.schedule(for: todo) }
        }
        try? modelContext.save()
    }

    private func delete() {
        services.notifications.cancel(for: todo)
        modelContext.delete(todo)
        try? modelContext.save()
    }
}

// MARK: - Local palette

private enum V2 {
    static let backgroundPrimary = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let backgroundSecondary = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let backgroundTertiary = Color(red: 0.94, green: 0.93, blue: 0.90)
    static let borderSecondary = Color(red: 0.80, green: 0.77, blue: 0.71)
    static let borderTertiary = Color(red: 0.88, green: 0.86, blue: 0.82)

    static let textPrimary = Color(red: 0.12, green: 0.10, blue: 0.09)
    static let textSecondary = Color(red: 0.42, green: 0.38, blue: 0.33)
    static let textTertiary = Color(red: 0.60, green: 0.55, blue: 0.48)

    static let accent = Color(red: 0.73, green: 0.46, blue: 0.09)
    static let accentBackground = Color(red: 0.99, green: 0.94, blue: 0.85)
    static let accentBorder = Color(red: 0.88, green: 0.73, blue: 0.47)

    static let danger = Color(red: 0.78, green: 0.22, blue: 0.22)
    static let dangerBackground = Color(red: 0.99, green: 0.91, blue: 0.90)

    static let success = Color(red: 0.30, green: 0.52, blue: 0.18)
    static let successBackground = Color(red: 0.90, green: 0.95, blue: 0.85)

    static let pink = Color(red: 0.83, green: 0.33, blue: 0.49)
}
