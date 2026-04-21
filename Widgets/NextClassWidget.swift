import WidgetKit
import SwiftUI

struct NextClassEntry: TimelineEntry {
    let date: Date
    let name: String
    let timeRange: String
    let room: String?
    let minutesUntil: Int
    let hasClass: Bool
}

struct NextClassProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextClassEntry {
        NextClassEntry(
            date: .now,
            name: "English IV",
            timeRange: "9:10 – 10:15",
            room: "MEM205",
            minutesUntil: 12,
            hasClass: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextClassEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextClassEntry>) -> Void) {
        var entries: [NextClassEntry] = []
        let now = Date()
        let cal = Calendar.current
        // Generate entries every 5 min for next 2 hours so widget updates during school day.
        for offset in stride(from: 0, to: 120, by: 5) {
            if let d = cal.date(byAdding: .minute, value: offset, to: now) {
                entries.append(makeEntry(for: d))
            }
        }
        let refreshDate = cal.date(byAdding: .hour, value: 2, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func makeEntry(for date: Date) -> NextClassEntry {
        if let (cls, start) = defaultSchedule.next(after: date) {
            let df = DateFormatter(); df.dateFormat = "HH:mm"
            var range = df.string(from: start)
            if let endDate = cls.endDate(on: start) {
                range += "–\(df.string(from: endDate))"
            }
            return NextClassEntry(
                date: date,
                name: cls.name,
                timeRange: range,
                room: cls.room,
                minutesUntil: max(0, Int(start.timeIntervalSince(date) / 60)),
                hasClass: true
            )
        }
        return NextClassEntry(
            date: date,
            name: "No more classes",
            timeRange: "—",
            room: nil,
            minutesUntil: 0,
            hasClass: false
        )
    }
}

struct NextClassWidgetView: View {
    let entry: NextClassEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT CLASS")
                .font(.system(size: 9, weight: .semibold))
                .kerning(1.0)
                .foregroundStyle(.secondary)
            Text(entry.name)
                .font(.system(size: family == .systemSmall ? 15 : 18, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if entry.hasClass {
                Text(entry.timeRange)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                if let room = entry.room {
                    Text(room)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(minutesLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tint)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var minutesLabel: String {
        if entry.minutesUntil == 0 { return "in progress" }
        if entry.minutesUntil < 60 { return "in \(entry.minutesUntil) min" }
        let hours = entry.minutesUntil / 60
        return "in \(hours) hr"
    }
}

struct NextClassWidget: Widget {
    let kind: String = "NextClassWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextClassProvider()) { entry in
            NextClassWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Class")
        .description("Shows your upcoming class.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
