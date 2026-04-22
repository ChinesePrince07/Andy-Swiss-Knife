import SwiftUI
import SwiftData

struct AthleticsPickerView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @State private var subscribed: Set<String> = AthleticSubscriptions.enabledIDs
    @State private var isSyncing = false
    @State private var query: String = ""

    private var filteredSports: [(sport: String, teams: [SuffieldTeam])] {
        let source = SuffieldAthletics.bySport
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return source }
        return source.compactMap { group in
            let filtered = group.teams.filter {
                $0.sport.lowercased().contains(q)
                || $0.displayName.lowercased().contains(q)
            }
            return filtered.isEmpty ? nil : (sport: group.sport, teams: filtered)
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

            ForEach(filteredSports, id: \.sport) { group in
                Section(group.sport) {
                    ForEach(group.teams) { team in
                        Toggle(isOn: binding(for: team)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(team.shortName)
                                    .font(AppType.body)
                                    .foregroundStyle(AppColors.primary)
                                if subscribed.contains(team.id) {
                                    Text("Syncing")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                        }
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
