import WidgetKit
import SwiftUI
import AppIntents

struct TodoEntry: TimelineEntry {
    let date: Date
    let todos: [TodoSnapshotDTO]
}

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: .now, todos: [
            TodoSnapshotDTO(id: UUID(), title: "English essay", isDone: false, dueDate: .now, createdAt: .now),
            TodoSnapshotDTO(id: UUID(), title: "Calc pset", isDone: false, dueDate: nil, createdAt: .now),
            TodoSnapshotDTO(id: UUID(), title: "Email Mr. Davis", isDone: true, dueDate: nil, createdAt: .now)
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
        let all = SnapshotStore.readTodos()
        let open = all.filter { !$0.isDone }.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.createdAt > b.createdAt
            }
        }
        return TodoEntry(date: .now, todos: Array(open.prefix(8)))
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
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.todos.isEmpty {
                Spacer()
                Text("All clear")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.todos.prefix(maxRows)) { t in
                    row(t)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("TODO")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(entry.todos.count)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.trailing, 10)
            Link(destination: URL(string: "swissknife://add-todo")!) {
                Image(systemName: "plus.square")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private func row(_ t: TodoSnapshotDTO) -> some View {
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
