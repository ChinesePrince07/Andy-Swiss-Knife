import SwiftUI
import SwiftData

struct AthleticsView: View {
    let services: Services
    @Environment(\.modelContext) private var modelContext

    @State private var games: [CachedEvent] = []
    @State private var didLoad = false

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if AthleticSubscriptions.enabledIDs.isEmpty {
                        noFeedState
                    } else if visibleGames.isEmpty {
                        emptyGamesState
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
        .onAppear {
            reload()
            Task { await sync(force: true) }
        }
    }

    private func reload() {
        let prefix = AthleticSubscriptions.sourcePrefix
        let descriptor = FetchDescriptor<CachedEvent>(
            sortBy: [SortDescriptor(\CachedEvent.start)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        games = all.filter { ($0.source ?? "").hasPrefix(prefix) }
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
            Text("No teams subscribed.")
                .font(AppType.body)
                .foregroundStyle(AppColors.secondary)
            Text("Pick your sports in Settings → Athletics.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.top, 20)
    }

    private var emptyGamesState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(didLoad ? "No upcoming games." : "Loading…")
                .font(AppType.body)
                .foregroundStyle(AppColors.secondary)
            if didLoad {
                Text("Teams with empty feeds are likely off-season.")
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.tertiary)
                Rectangle().fill(AppColors.tertiary).frame(height: 1).padding(.vertical, 2)
                ForEach(Array(AthleticSubscriptions.enabledIDs).sorted(), id: \.self) { id in
                    subscribedRow(teamID: id)
                }
            }
        }
        .padding(.top, 20)
    }

    private func subscribedRow(teamID: String) -> some View {
        let team = SuffieldAthletics.team(for: teamID)
        let count = games.filter { ($0.source ?? "") == AthleticSubscriptions.sourceKey(for: teamID) }.count
        return HStack(alignment: .firstTextBaseline) {
            Text(team?.displayName ?? "Team \(teamID)")
                .font(AppType.body)
                .foregroundStyle(AppColors.primary)
            if let season = team?.season {
                Text(season.title.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .kerning(1.1)
                    .foregroundStyle(AppColors.tertiary)
            }
            Spacer()
            Text("\(count) games")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(count == 0 ? AppColors.accent : AppColors.secondary)
        }
        .padding(.vertical, 4)
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
        let parsed = parseTitle(g.title)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeLabel(g))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.secondary)
                if let tag = parsed.tag {
                    Text(tag.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .kerning(1.1)
                        .foregroundStyle(tag == "Home" ? AppColors.primary : AppColors.accent)
                }
            }
            .frame(width: 62, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(parsed.opponent)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(AppColors.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let team = g.calendarTitle {
                        Text(team)
                            .font(AppType.caption)
                            .foregroundStyle(AppColors.accent)
                            .lineLimit(1)
                    }
                    if let loc = g.location, !loc.isEmpty {
                        Text("· \(loc)")
                            .font(AppType.caption)
                            .foregroundStyle(AppColors.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 5)
    }

    private struct ParsedTitle {
        let opponent: String
        let tag: String?
    }

    private func parseTitle(_ raw: String) -> ParsedTitle {
        var s = raw
        var tag: String?
        if let range = s.range(of: #"\((Home|Away|TBD)\)"#, options: .regularExpression) {
            let matched = String(s[range]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            tag = matched
            s.removeSubrange(range)
        }
        if let vsRange = s.range(of: " vs. ") {
            s = String(s[vsRange.upperBound...])
        } else if let vsRange = s.range(of: " vs ") {
            s = String(s[vsRange.upperBound...])
        }
        return ParsedTitle(opponent: s.trimmingCharacters(in: .whitespaces), tag: tag)
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
        await services.athletics.syncAllEnabled(forceRefresh: force)
        didLoad = true
        reload()
    }
}
