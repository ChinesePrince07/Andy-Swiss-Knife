import Foundation
import SwiftData

@MainActor
enum AthleticSubscriptions {
    private static let key = "athletics.subscribedTeamIDs.v1"
    static let sourcePrefix = "athletics-"

    static var enabledIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    static func isEnabled(_ teamID: String) -> Bool { enabledIDs.contains(teamID) }

    static func set(_ teamID: String, enabled: Bool) {
        var ids = enabledIDs
        if enabled { ids.insert(teamID) } else { ids.remove(teamID) }
        enabledIDs = ids
    }

    static func sourceKey(for teamID: String) -> String {
        sourcePrefix + teamID
    }
}

@MainActor
final class AthleticsService {
    private let http: HTTPClient
    private let context: ModelContext
    private let cacheTTL: TimeInterval = 6 * 60 * 60

    init(http: HTTPClient, context: ModelContext) {
        self.http = http
        self.context = context
    }

    /// Syncs every currently-subscribed team. Call on app launch, on pull-
    /// to-refresh, and when the user toggles a team on.
    @discardableResult
    func syncAllEnabled(forceRefresh: Bool = false) async -> Int {
        let ids = AthleticSubscriptions.enabledIDs
        guard !ids.isEmpty else { return 0 }
        let lastSync = UserDefaults.standard.object(forKey: "lastSync.athletics") as? Date
        let lastSyncedIDs = Set(UserDefaults.standard.stringArray(forKey: "lastSync.athletics.ids") ?? [])
        let newTeamAdded = !ids.isSubset(of: lastSyncedIDs)
        if !forceRefresh, !newTeamAdded, let last = lastSync,
           Date.now.timeIntervalSince(last) < cacheTTL {
            return 0
        }
        var added = 0
        for id in ids {
            guard let team = SuffieldAthletics.team(for: id) else { continue }
            added += await sync(team: team)
        }
        UserDefaults.standard.set(Date.now, forKey: "lastSync.athletics")
        UserDefaults.standard.set(Array(ids), forKey: "lastSync.athletics.ids")
        return added
    }

    @discardableResult
    func sync(team: SuffieldTeam) async -> Int {
        let data: Data
        do { data = try await http.data(for: team.feedURL) } catch { return 0 }
        let source = String(data: data, encoding: .utf8) ?? ""
        guard let events = try? ICSParser.parse(source) else { return 0 }

        let cal = Calendar.current
        let windowStart = cal.startOfDay(for: .now)
        guard let windowEnd = cal.date(byAdding: .day, value: 365, to: windowStart) else { return 0 }

        var expanded: [ICSEvent] = []
        for e in events {
            expanded.append(contentsOf: RRuleExpander.expand(event: e, from: windowStart, to: windowEnd, calendar: cal))
        }

        let sourceKey = AthleticSubscriptions.sourceKey(for: team.id)
        let descriptor = FetchDescriptor<CachedEvent>(
            predicate: #Predicate { $0.source == sourceKey }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        // Accept both storage shapes: legacy rows keyed by raw UID, new rows
        // keyed by "<source>:<uid>". Look up by raw UID; do not mutate the
        // unique primary key on legacy rows — SwiftData rejects PK mutation.
        var existingByUID: [String: CachedEvent] = [:]
        for row in existing {
            let uid = row.id.hasPrefix(sourceKey + ":") ? String(row.id.dropFirst(sourceKey.count + 1)) : row.id
            existingByUID[uid] = row
        }

        var keep = Set<String>()
        var added = 0
        for e in expanded {
            keep.insert(e.uid)
            if let row = existingByUID[e.uid] {
                row.title = e.summary
                row.start = e.start
                row.end = e.end
                row.location = e.location
                row.calendarTitle = team.displayName
            } else {
                let storedID = "\(sourceKey):\(e.uid)"
                context.insert(CachedEvent(
                    id: storedID,
                    title: e.summary,
                    start: e.start,
                    end: e.end,
                    location: e.location,
                    source: sourceKey,
                    calendarTitle: team.displayName
                ))
                added += 1
            }
        }
        for (uid, row) in existingByUID where !keep.contains(uid) || row.end < windowStart {
            context.delete(row)
        }
        do {
            try context.save()
        } catch {
            print("[AthleticsService] save failed for \(team.id): \(error)")
        }
        return added
    }

    func removeEvents(forTeamID id: String) {
        let key = AthleticSubscriptions.sourceKey(for: id)
        let predicate = #Predicate<CachedEvent> { $0.source == key }
        let rows = (try? context.fetch(FetchDescriptor<CachedEvent>(predicate: predicate))) ?? []
        for r in rows { context.delete(r) }
        try? context.save()
    }

    func nextUpcoming(now: Date = .now) -> CachedEvent? {
        let prefix = AthleticSubscriptions.sourcePrefix
        let descriptor = FetchDescriptor<CachedEvent>(
            sortBy: [SortDescriptor(\CachedEvent.start)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.first { event in
            guard let src = event.source, src.hasPrefix(prefix) else { return false }
            return event.start >= now
        }
    }
}
