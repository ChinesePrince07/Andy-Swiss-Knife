import Foundation
import SwiftData

@MainActor
final class AthleticsService {
    static let sourceKey = "athletics"

    private let http: HTTPClient
    private let context: ModelContext
    private let cacheTTL: TimeInterval = 12 * 60 * 60

    init(http: HTTPClient, context: ModelContext) {
        self.http = http
        self.context = context
    }

    @discardableResult
    func sync(forceRefresh: Bool = false) async -> Int {
        let raw = UserSettings.shared.athleticsFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw) else { return 0 }

        let lastSync = UserDefaults.standard.object(forKey: "lastSync.athletics") as? Date
        let needsFetch = forceRefresh || lastSync == nil
            || Date.now.timeIntervalSince(lastSync!) > cacheTTL
        guard needsFetch else { return 0 }

        let data: Data
        do { data = try await http.data(for: url) } catch { return 0 }
        let source = String(data: data, encoding: .utf8) ?? ""
        guard let events = try? ICSParser.parse(source) else { return 0 }

        let cal = Calendar.current
        let windowStart = cal.startOfDay(for: .now)
        guard let windowEnd = cal.date(byAdding: .day, value: 365, to: windowStart) else { return 0 }

        var expanded: [ICSEvent] = []
        for e in events {
            expanded.append(contentsOf: RRuleExpander.expand(event: e, from: windowStart, to: windowEnd, calendar: cal))
        }

        let key = Self.sourceKey
        let descriptor = FetchDescriptor<CachedEvent>(
            predicate: #Predicate { $0.source == key }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        var keep = Set<String>()
        var added = 0
        for e in expanded {
            keep.insert(e.uid)
            if let row = existingByID[e.uid] {
                row.title = e.summary
                row.start = e.start
                row.end = e.end
                row.location = e.location
            } else {
                context.insert(CachedEvent(
                    id: e.uid,
                    title: e.summary,
                    start: e.start,
                    end: e.end,
                    location: e.location,
                    source: AthleticsService.sourceKey
                ))
                added += 1
            }
        }
        for (id, row) in existingByID where !keep.contains(id) || row.end < windowStart {
            context.delete(row)
        }
        try? context.save()
        UserDefaults.standard.set(Date.now, forKey: "lastSync.athletics")
        return added
    }

    func nextUpcoming(now: Date = .now) -> CachedEvent? {
        let key = Self.sourceKey
        var descriptor = FetchDescriptor<CachedEvent>(
            predicate: #Predicate { $0.source == key && $0.start >= now },
            sortBy: [SortDescriptor(\.start)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
