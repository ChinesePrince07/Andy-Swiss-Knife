import WidgetKit
import SwiftUI

struct MenuEntry: TimelineEntry {
    let date: Date
    let dateKey: String
    let lunch: String
    let dinner: String
    let fetchedAt: Date?
}

struct MenuProvider: TimelineProvider {
    func placeholder(in context: Context) -> MenuEntry {
        MenuEntry(
            date: .now,
            dateKey: "2026-04-21",
            lunch: "Spicy Rigatoni, Sweet Sausage and Peppers",
            dinner: "Beef Birria Tacos, Cilantro Rice",
            fetchedAt: .now
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MenuEntry) -> Void) {
        completion(fetch())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MenuEntry>) -> Void) {
        let entry = fetch()
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func fetch() -> MenuEntry {
        struct Snapshot: Codable {
            let dateKey: String
            let breakfast: String
            let lunch: String
            let dinner: String
            let fetchedAt: Date
        }
        guard let data = SharedStorage.defaults.data(forKey: SharedStorage.Keys.menu),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return MenuEntry(date: .now, dateKey: "", lunch: "", dinner: "", fetchedAt: nil)
        }
        return MenuEntry(
            date: .now,
            dateKey: snap.dateKey,
            lunch: snap.lunch,
            dinner: snap.dinner,
            fetchedAt: snap.fetchedAt
        )
    }
}

struct MenuWidgetView: View {
    let entry: MenuEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weekdayLabel)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("MENU")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(.secondary)
            }

            if entry.lunch.isEmpty && entry.dinner.isEmpty {
                Spacer()
                Text("Menu unavailable")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Text("Open app to sync")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                if !entry.lunch.isEmpty {
                    mealSection(label: "LUNCH", text: entry.lunch)
                }
                if family != .systemSmall, !entry.dinner.isEmpty {
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 0.5)
                    mealSection(label: "DINNER", text: entry.dinner)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private func mealSection(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(.secondary)
            Text(collapseText(text))
                .font(.system(size: family == .systemSmall ? 10 : 12,
                              weight: .regular, design: .monospaced))
                .lineLimit(family == .systemSmall ? 3 : (family == .systemMedium ? 2 : 5))
                .foregroundStyle(.primary)
        }
    }

    private func collapseText(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: ", ")
    }

    private var weekdayLabel: String {
        let df = DateFormatter(); df.dateFormat = "EEEE"
        return df.string(from: .now).uppercased()
    }
}

struct MenuWidget: Widget {
    let kind: String = "MenuWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MenuProvider()) { entry in
            MenuWidgetView(entry: entry)
        }
        .configurationDisplayName("Menu")
        .description("Today's lunch and dinner from Suffield dining.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
