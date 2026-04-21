import Foundation
import SwiftData

@MainActor
final class EventsService {
    private let http: HTTPClient
    private let context: ModelContext
    private let calendar: Calendar
    private let cacheTTL: TimeInterval = 24 * 60 * 60

    init(http: HTTPClient, context: ModelContext, calendar: Calendar = .current) {
        self.http = http
        self.context = context
        self.calendar = calendar
    }

    func upcomingEvents(now: Date = .now, days: Int = 7, forceRefresh: Bool = false) async throws -> [Event] {
        let lastSync = UserDefaults.standard.object(forKey: "lastSync.events") as? Date
        let needsFetch = forceRefresh || lastSync == nil
            || now.timeIntervalSince(lastSync!) > cacheTTL

        if needsFetch {
            try await refresh(now: now, days: days)
        }
        return try cachedWithinWindow(now: now, days: days)
    }

    private func refresh(now: Date, days: Int) async throws {
        let data = try await http.data(for: Config.eventsICSURL)
        let source = String(data: data, encoding: .utf8) ?? ""
        let raw = try ICSParser.parse(source)

        let windowStart = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: days + 30, to: windowStart) else { return }

        var expanded: [ICSEvent] = []
        for e in raw {
            expanded.append(contentsOf: RRuleExpander.expand(event: e, from: windowStart, to: windowEnd, calendar: calendar))
        }

        let descriptor = FetchDescriptor<CachedEvent>(
            predicate: #Predicate { $0.source == "school" || $0.source == nil }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        var keepIDs = Set<String>()
        for e in expanded {
            keepIDs.insert(e.uid)
            if let cached = existingByID[e.uid] {
                cached.title = e.summary
                cached.start = e.start
                cached.end = e.end
                cached.location = e.location
                cached.source = "school"
            } else {
                context.insert(CachedEvent(
                    id: e.uid,
                    title: e.summary,
                    start: e.start,
                    end: e.end,
                    location: e.location,
                    source: "school"
                ))
            }
        }

        for (id, cached) in existingByID where !keepIDs.contains(id) || cached.end < windowStart {
            context.delete(cached)
        }

        try? context.save()
        UserDefaults.standard.set(now, forKey: "lastSync.events")
    }

    private func cachedWithinWindow(now: Date, days: Int) throws -> [Event] {
        let windowStart = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: days, to: windowStart) else { return [] }

        let predicate = #Predicate<CachedEvent> { $0.end >= windowStart && $0.start <= windowEnd }
        let desc = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\CachedEvent.start)])
        let cached = try context.fetch(desc)
        return cached.map {
            Event(id: $0.id, title: $0.title, start: $0.start, end: $0.end, location: $0.location)
        }
    }
}
