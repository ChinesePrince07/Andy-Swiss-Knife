import Foundation
import EventKit
import SwiftData

struct ImportableCalendar: Identifiable, Hashable {
    let id: String            // EKCalendar.calendarIdentifier
    let title: String
    let sourceTitle: String
    let colorHex: String
}

enum CalendarImportError: Error {
    case accessDenied
    case notDetermined
}

/// Persists the set of Apple Calendar IDs the user has toggled on.
/// Each toggle-on triggers a sync; toggle-off removes that calendar's events.
@MainActor
enum CalendarToggleStore {
    private static let key = "calendar.enabledIDs.v1"

    static var enabledIDs: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: key)
        }
    }

    static func isEnabled(_ id: String) -> Bool { enabledIDs.contains(id) }

    static func set(_ id: String, enabled: Bool) {
        var current = enabledIDs
        if enabled { current.insert(id) } else { current.remove(id) }
        enabledIDs = current
    }
}

@MainActor
final class CalendarImporter {
    private let store: EKEventStore
    private let context: ModelContext
    private static let sourcePrefix = "apple-cal-"

    init(context: ModelContext) {
        self.store = EKEventStore()
        self.context = context
    }

    static func sourceKey(for calendarID: String) -> String {
        "\(sourcePrefix)\(calendarID)"
    }

    func requestAccess() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess: return true
        case .denied, .restricted: throw CalendarImportError.accessDenied
        default:
            return try await store.requestFullAccessToEvents()
        }
    }

    func availableCalendars() -> [ImportableCalendar] {
        store.calendars(for: .event).map {
            ImportableCalendar(
                id: $0.calendarIdentifier,
                title: $0.title,
                sourceTitle: $0.source.title,
                colorHex: String(format: "#%06x", colorInt($0.cgColor))
            )
        }
    }

    /// Sync every currently-enabled calendar. Call on app launch and
    /// after toggle changes.
    @discardableResult
    func syncEnabled(daysAhead: Int = 365, daysBehind: Int = 1) -> Int {
        syncCalendars(ids: Array(CalendarToggleStore.enabledIDs),
                      daysAhead: daysAhead, daysBehind: daysBehind)
    }

    @discardableResult
    func syncCalendars(ids: [String], daysAhead: Int = 365, daysBehind: Int = 1) -> Int {
        guard !ids.isEmpty else { return 0 }
        let calendars = store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return 0 }

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -daysBehind, to: .now) ?? .now
        let end = cal.date(byAdding: .day, value: daysAhead, to: .now) ?? .now

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)

        // Per-calendar upsert.
        var totalNew = 0
        for ek in events {
            guard let calID = ek.calendar?.calendarIdentifier else { continue }
            let source = Self.sourceKey(for: calID)
            let extID = ek.eventIdentifier.map { "\(source)-\($0)" } ?? "\(source)-\(UUID().uuidString)"

            let predicate = #Predicate<CachedEvent> { $0.id == extID }
            let existing = try? context.fetch(FetchDescriptor<CachedEvent>(predicate: predicate)).first
            if let existing {
                existing.title = ek.title ?? "(no title)"
                existing.start = ek.startDate ?? .now
                existing.end = ek.endDate ?? ek.startDate ?? .now
                existing.location = ek.location
                existing.calendarTitle = ek.calendar?.title
            } else {
                context.insert(CachedEvent(
                    id: extID,
                    title: ek.title ?? "(no title)",
                    start: ek.startDate ?? .now,
                    end: ek.endDate ?? ek.startDate ?? .now,
                    location: ek.location,
                    source: source,
                    calendarTitle: ek.calendar?.title
                ))
                totalNew += 1
            }
        }
        try? context.save()
        return totalNew
    }

    /// Remove every CachedEvent sourced from the given calendar ID.
    func removeEvents(forCalendarID calendarID: String) {
        let source = Self.sourceKey(for: calendarID)
        let predicate = #Predicate<CachedEvent> { $0.source == source }
        let rows = (try? context.fetch(FetchDescriptor<CachedEvent>(predicate: predicate))) ?? []
        for r in rows { context.delete(r) }
        try? context.save()
    }

    private func colorInt(_ cg: CGColor?) -> Int {
        guard let cg, let components = cg.components, components.count >= 3 else { return 0x888888 }
        let r = Int(components[0] * 255) & 0xff
        let g = Int(components[1] * 255) & 0xff
        let b = Int(components[2] * 255) & 0xff
        return (r << 16) | (g << 8) | b
    }
}
