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
        List {
            if !subscribed.isEmpty {
                Section {
                    Text("\(subscribed.count) subscribed")
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                    Button(role: .destructive) {
                        unsubscribeAll()
                    } label: {
                        Text("Unsubscribe from all")
                    }
                }
            }

            ForEach(AthleticSeason.allCases, id: \.self) { season in
                let buckets = bucketsForSeason(season)
                if !buckets.isEmpty {
                    Section {
                        ForEach(buckets, id: \.sport) { bucket in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bucket.sport)
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .kerning(1.1)
                                    .foregroundStyle(AppColors.tertiary)
                                    .padding(.top, 4)
                                ForEach(bucket.teams) { team in
                                    Toggle(isOn: binding(for: team)) {
                                        Text(team.shortName)
                                            .font(AppType.body)
                                            .foregroundStyle(AppColors.primary)
                                    }
                                    .padding(.leading, 2)
                                }
                            }
                        }
                    } header: {
                        Text(season.title.uppercased())
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Filter sports")
        .navigationTitle("Athletics teams")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Syncing…").font(AppType.caption)
                }
                .padding(10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 20)
            }
        }
    }

    private func binding(for team: SuffieldTeam) -> Binding<Bool> {
        Binding(
            get: { subscribed.contains(team.id) },
            set: { newValue in
                toggle(team, on: newValue)
            }
        )
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
