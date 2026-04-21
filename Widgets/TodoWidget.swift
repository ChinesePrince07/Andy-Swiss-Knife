import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct TodoSnapshot: Identifiable {
    let id: UUID
    let title: String
    let isDone: Bool
    let dueDate: Date?
}

struct TodoEntry: TimelineEntry {
    let date: Date
    let todos: [TodoSnapshot]
}

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: .now, todos: [
            TodoSnapshot(id: UUID(), title: "English essay", isDone: false, dueDate: .now),
            TodoSnapshot(id: UUID(), title: "Calc pset", isDone: false, dueDate: nil),
            TodoSnapshot(id: UUID(), title: "Email Mr. Davis", isDone: true, dueDate: nil)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(fetch())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let entry = fetch()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func fetch() -> TodoEntry {
        guard let container = try? AppModelContainer.make() else {
            return TodoEntry(date: .now, todos: [])
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate { $0.externalID == nil }
        )
        let todos = (try? context.fetch(descriptor)) ?? []
        let open = todos.filter { !$0.isDone }.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.createdAt > b.createdAt
            }
        }
        let snapshots = open.prefix(6).map {
            TodoSnapshot(id: $0.id, title: $0.title, isDone: $0.isDone, dueDate: $0.dueDate)
        }
        return TodoEntry(date: .now, todos: Array(snapshots))
    }
}

struct TodoWidgetView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) private var family

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemLarge: return 8
        default: return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODO")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.todos.count) open")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if entry.todos.isEmpty {
                Spacer()
                Text("All clear")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.todos.prefix(maxRows)) { t in
                    HStack(spacing: 8) {
                        Button(intent: ToggleTodoIntent(todoID: t.id.uuidString)) {
                            Image(systemName: t.isDone ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        Text(t.title)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                            .strikethrough(t.isDone)
                            .foregroundStyle(t.isDone ? .secondary : .primary)
                        Spacer(minLength: 4)
                        if let due = t.dueDate, Calendar.current.isDateInToday(due) {
                            Text("TODAY")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct TodoWidget: Widget {
    let kind: String = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("Todos")
        .description("Check off tasks right from the home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
