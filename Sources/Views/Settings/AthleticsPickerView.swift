import SwiftUI
import SwiftData

struct AthleticsPickerView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @State private var subscribed: Set<String> = AthleticSubscriptions.enabledIDs
    @State private var isSyncing = false
    @State private var query: String = ""

    private struct SportBucket: Hashable {
        let sport: String
        let teams: [SuffieldTeam]
    }

    private func bucketsForSeason(_ season: AthleticSeason) -> [SportBucket] {
        let raw = SuffieldAthletics.teams(in: season)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return raw.compactMap { group in
            let filtered = q.isEmpty
                ? group.teams
                : group.teams.filter {
                    $0.sport.lowercased().contains(q)
                    || $0.displayName.lowercased().contains(q)
                }
            return filtered.isEmpty ? nil : SportBucket(sport: group.sport, teams: filtered)
        }
    }

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    searchField
                    if !subscribed.isEmpty { subscribedSummary }
                    ForEach(AthleticSeason.allCases, id: \.self) { season in
                        let buckets = bucketsForSeason(season)
                        if !buckets.isEmpty {
                            seasonSection(season: season, buckets: buckets)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Athletics teams")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Syncing…")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .kerning(1.1)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 2))
                .padding(.bottom, 24)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.tertiary)
            TextField("Filter sports", text: $query)
                .textInputAutocapitalization(.never)
                .foregroundStyle(AppColors.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
    }

    private var subscribedSummary: some View {
        HStack {
            Text("\(subscribed.count) SUBSCRIBED")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.primary)
            Spacer()
            Button { unsubscribeAll() } label: {
                Text("CLEAR")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.1)
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(Rectangle().strokeBorder(AppColors.accent, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
    }

    private func seasonSection(season: AthleticSeason, buckets: [SportBucket]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(season.title.uppercased())
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(AppColors.primary)
            Rectangle().fill(AppColors.primary).frame(height: 2)

            ForEach(buckets, id: \.sport) { bucket in
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.sport.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(AppColors.tertiary)
                        .padding(.top, 6)
                    ForEach(bucket.teams) { team in
                        teamRow(team)
                        HairlineDivider()
                    }
                }
            }
        }
    }

    private func teamRow(_ team: SuffieldTeam) -> some View {
        let on = subscribed.contains(team.id)
        return Button {
            toggle(team, on: !on)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle()
                        .strokeBorder(AppColors.primary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if on {
                        Rectangle()
                            .fill(AppColors.primary)
                            .frame(width: 14, height: 14)
                    }
                }
                Text(team.shortName)
                    .font(AppType.body)
                    .foregroundStyle(AppColors.primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ team: SuffieldTeam, on: Bool) {
        if on { subscribed.insert(team.id) } else { subscribed.remove(team.id) }
        AthleticSubscriptions.set(team.id, enabled: on)
        Task { await runSync(for: team, enabled: on) }
    }

    private func unsubscribeAll() {
        let ids = subscribed
        subscribed.removeAll()
        for id in ids {
            AthleticSubscriptions.set(id, enabled: false)
            services.athletics.removeEvents(forTeamID: id)
        }
    }

    private func runSync(for team: SuffieldTeam, enabled: Bool) async {
        isSyncing = true
        if enabled {
            _ = await services.athletics.sync(team: team)
        } else {
            services.athletics.removeEvents(forTeamID: team.id)
        }
        isSyncing = false
    }
}
