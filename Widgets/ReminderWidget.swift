import WidgetKit
import SwiftUI

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [ReminderSnapshotDTO]
}

struct ReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: .now, reminders: [
            ReminderSnapshotDTO(id: UUID(), title: "Pick up suit", date: .now.addingTimeInterval(3600), isAllDay: false, notes: nil),
            ReminderSnapshotDTO(id: UUID(), title: "Dentist", date: .now.addingTimeInterval(86400), isAllDay: false, notes: nil)
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
        let all = SnapshotStore.readReminders()
        let upcoming = all.filter { $0.date >= .now }.sorted { $0.date < $1.date }
        return ReminderEntry(date: .now, reminders: Array(upcoming.prefix(6)))
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
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.reminders.isEmpty {
                Spacer()
                Text("Nothing upcoming")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.reminders.prefix(maxRows)) { r in
                    row(r)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("REMINDERS")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(entry.reminders.count)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.trailing, 10)
            Link(destination: URL(string: "swissknife://add-reminder")!) {
                Image(systemName: "plus.square")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private func row(_ r: ReminderSnapshotDTO) -> some View {
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

    private func dateLabel(_ r: ReminderSnapshotDTO) -> String {
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
