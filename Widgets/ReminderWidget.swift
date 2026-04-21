import WidgetKit
import SwiftUI
import SwiftData

struct ReminderSnapshot: Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let isAllDay: Bool
    let notes: String?
}

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [ReminderSnapshot]
}

struct ReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: .now, reminders: [
            ReminderSnapshot(id: UUID(), title: "Pick up suit", date: .now.addingTimeInterval(3600), isAllDay: false, notes: nil),
            ReminderSnapshot(id: UUID(), title: "Dentist", date: .now.addingTimeInterval(86400), isAllDay: false, notes: nil)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> Void) {
        completion(fetch())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> Void) {
        let entry = fetch()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func fetch() -> ReminderEntry {
        guard let container = try? AppModelContainer.make() else {
            return ReminderEntry(date: .now, reminders: [])
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PersonalEvent>(
            sortBy: [SortDescriptor(\.date)]
        )
        let events = (try? context.fetch(descriptor)) ?? []
        let upcoming = events.filter { $0.date >= .now }.prefix(5)
        let snapshots = upcoming.map {
            ReminderSnapshot(id: $0.id, title: $0.title, date: $0.date, isAllDay: $0.isAllDay, notes: $0.notes)
        }
        return ReminderEntry(date: .now, reminders: Array(snapshots))
    }
}

struct ReminderWidgetView: View {
    let entry: ReminderEntry
    @Environment(\.widgetFamily) private var family

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 3
        case .systemLarge: return 6
        default: return 2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("REMINDERS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.reminders.count)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if entry.reminders.isEmpty {
                Spacer()
                Text("Nothing upcoming")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.reminders.prefix(maxRows)) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(dateLabel(r))
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if let notes = r.notes, !notes.isEmpty {
                                Text("·")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(notes)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private func dateLabel(_ r: ReminderSnapshot) -> String {
        let cal = Calendar.current
        let df = DateFormatter()
        if r.isAllDay {
            if cal.isDateInToday(r.date) { return "today" }
            if cal.isDateInTomorrow(r.date) { return "tomorrow" }
            df.dateFormat = "EEE MMM d"
        } else {
            if cal.isDateInToday(r.date) {
                df.dateFormat = "'today' HH:mm"
            } else if cal.isDateInTomorrow(r.date) {
                df.dateFormat = "'tmrw' HH:mm"
            } else {
                df.dateFormat = "EEE HH:mm"
            }
        }
        return df.string(from: r.date)
    }
}

struct ReminderWidget: Widget {
    let kind: String = "ReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            ReminderWidgetView(entry: entry)
        }
        .configurationDisplayName("Reminders")
        .description("Upcoming personal reminders.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
