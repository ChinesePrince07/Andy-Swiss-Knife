import SwiftUI
import SwiftData

struct AthleticsView: View {
    let services: Services
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<CachedEvent> { $0.source == "athletics" },
           sort: \CachedEvent.start)
    private var games: [CachedEvent]

    @State private var didLoad = false

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if UserSettings.shared.athleticsFeedURL.isEmpty {
                        noFeedState
                    } else if visibleGames.isEmpty {
                        Text(didLoad ? "No upcoming games." : "Loading…")
                            .font(AppType.body)
                            .foregroundStyle(AppColors.secondary)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(grouped, id: \.0) { day, list in
                            daySection(day: day, games: list)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Athletics")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await sync(force: true) }
        .task { await sync(force: false) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Games")
                .font(AppType.displayTitle)
                .foregroundStyle(AppColors.primary)
            Text("\(visibleGames.count) upcoming")
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
        }
    }

    private var noFeedState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No athletics feed set.")
                .font(AppType.body)
                .foregroundStyle(AppColors.secondary)
            Text("Paste the athletic schedule ICS URL in Settings → Events.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.top, 20)
    }

    private var visibleGames: [CachedEvent] {
        games.filter { $0.end >= .now }
    }

    private var grouped: [(Date, [CachedEvent])] {
        let cal = Calendar.current
        let map = Dictionary(grouping: visibleGames) { cal.startOfDay(for: $0.start) }
        return map.keys.sorted().map { key in
            (key, (map[key] ?? []).sorted { $0.start < $1.start })
        }
    }

    private func daySection(day: Date, games: [CachedEvent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dayHeader(day))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.primary)
            Rectangle().fill(AppColors.primary).frame(height: 1)
            ForEach(games) { g in
                gameRow(g)
                HairlineDivider()
            }
        }
    }

    private func gameRow(_ g: CachedEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(timeLabel(g))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .frame(width: 78, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(g.title)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(AppColors.primary)
                if let loc = g.location, !loc.isEmpty {
                    Text(loc)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func dayHeader(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "TODAY" }
        if cal.isDateInTomorrow(d) { return "TOMORROW" }
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: d).uppercased()
    }

    private func timeLabel(_ g: CachedEvent) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: g.start)
    }

    private func sync(force: Bool) async {
        await services.athletics.sync(forceRefresh: force)
        didLoad = true
    }
}
