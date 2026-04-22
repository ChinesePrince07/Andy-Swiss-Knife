import SwiftUI

/// Bucket categorization used by both AssignmentsView and the dashboard todo
/// section. Keeps the due-date emphasis consistent.
enum DueBucket: Hashable {
    case overdue
    case today
    case tomorrow
    case thisWeek
    case later(Date)   // exact day bucket beyond this week
    case someday       // no due date
    case done

    var order: Int {
        switch self {
        case .overdue: return 0
        case .today: return 1
        case .tomorrow: return 2
        case .thisWeek: return 3
        case .later(let d): return 4 + Int(d.timeIntervalSince1970 / 86400)
        case .someday: return 1_000_000
        case .done: return 1_000_001
        }
    }

    var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This week"
        case .later(let d):
            let df = DateFormatter(); df.dateFormat = "EEEE, MMM d"
            return df.string(from: d)
        case .someday: return "Someday"
        case .done: return "Done"
        }
    }

    var subtitle: String? {
        switch self {
        case .today, .tomorrow, .thisWeek:
            let df = DateFormatter(); df.dateFormat = "MMM d"
            let target: Date? = {
                let cal = Calendar.current
                switch self {
                case .today: return .now
                case .tomorrow: return cal.date(byAdding: .day, value: 1, to: .now)
                default: return nil
                }
            }()
            return target.map(df.string)
        default: return nil
        }
    }

    var isUrgent: Bool {
        switch self {
        case .overdue, .today: return true
        default: return false
        }
    }

    static func bucket(for date: Date?, now: Date = .now, calendar: Calendar = .current) -> DueBucket {
        guard let date else { return .someday }
        let startToday = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: date)
        if startDay < startToday { return .overdue }
        if calendar.isDate(startDay, inSameDayAs: startToday) { return .today }
        if let tmrw = calendar.date(byAdding: .day, value: 1, to: startToday),
           calendar.isDate(startDay, inSameDayAs: tmrw) {
            return .tomorrow
        }
        if let weekEnd = calendar.date(byAdding: .day, value: 7, to: startToday),
           startDay < weekEnd {
            return .thisWeek
        }
        return .later(startDay)
    }

    static func group(todos: [Todo]) -> [(DueBucket, [Todo])] {
        var map: [DueBucket: [Todo]] = [:]
        for t in todos {
            let b = bucket(for: t.dueDate)
            map[b, default: []].append(t)
        }
        let sortedKeys = map.keys.sorted { $0.order < $1.order }
        return sortedKeys.map { key in
            let raw = map[key] ?? []
            let items: [Todo]
            if case .someday = key {
                items = raw.sorted { lhs, rhs in
                    let l = lhs.sortOrder ?? lhs.createdAt.timeIntervalSince1970
                    let r = rhs.sortOrder ?? rhs.createdAt.timeIntervalSince1970
                    return l > r
                }
            } else {
                items = raw.sorted { lhs, rhs in
                    switch (lhs.dueDate, rhs.dueDate) {
                    case let (.some(l), .some(r)): return l < r
                    case (.some, .none): return true
                    case (.none, .some): return false
                    default: return lhs.createdAt > rhs.createdAt
                    }
                }
            }
            return (key, items)
        }
    }
}

struct DueGroupSection: View {
    let title: String
    let subtitle: String?
    let isUrgent: Bool
    let items: [Todo]
    let services: Services
    var allowReorder: Bool = false

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .kerning(1.4)
                    .foregroundStyle(isUrgent ? AppColors.accent : AppColors.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.tertiary)
                }
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
            }
            Rectangle()
                .fill(isUrgent ? AppColors.accent : AppColors.primary)
                .frame(height: isUrgent ? 2 : 1)
                .padding(.bottom, 2)
            ForEach(items) { todo in
                Group {
                    if allowReorder {
                        TodoRow(todo: todo, services: services)
                            .draggable(todo.id.uuidString)
                            .dropDestination(for: String.self) { dropped, _ in
                                handleDrop(droppedIDs: dropped, target: todo)
                            }
                    } else {
                        TodoRow(todo: todo, services: services)
                    }
                }
                HairlineDivider()
            }
        }
    }

    private func handleDrop(droppedIDs: [String], target: Todo) -> Bool {
        guard let raw = droppedIDs.first, let droppedUUID = UUID(uuidString: raw) else { return false }
        guard let dropped = items.first(where: { $0.id == droppedUUID }), dropped.id != target.id else { return false }
        var arr = items
        arr.removeAll { $0.id == dropped.id }
        guard let idx = arr.firstIndex(where: { $0.id == target.id }) else { return false }
        arr.insert(dropped, at: idx)
        // Newest on top: assign descending sortOrder by new position.
        let total = arr.count
        for (i, t) in arr.enumerated() {
            t.sortOrder = Double(total - i)
        }
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
        return true
    }
}
