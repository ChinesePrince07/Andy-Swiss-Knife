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

@MainActor
final class CalendarImporter {
    private let store: EKEventStore
    private let context: ModelContext

    init(context: ModelContext) {
        self.store = EKEventStore()
        self.context = context
    }

    /// Request full access to calendars. Returns true if granted.
    func requestAccess() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess: return true
        case .denied, .restricted: throw CalendarImportError.accessDenied
        default:
            let granted = try await store.requestFullAccessToEvents()
            return granted
        }
    }

    /// List every calendar available on the device.
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

    /// Import events from given calendar IDs within the next `daysAhead` days.
    /// Upserts by EKEvent.eventIdentifier so repeat imports don't duplicate.
    @discardableResult
    func importEvents(fromCalendarIDs ids: [String], daysAhead: Int = 90, daysBehind: Int = 1) -> Int {
        let calendars = store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return 0 }

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -daysBehind, to: .now) ?? .now
        let end = cal.date(byAdding: .day, value: daysAhead, to: .now) ?? .now

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)

        let existing = (try? context.fetch(
            FetchDescriptor<PersonalEvent>(predicate: #Predicate { $0.externalID != nil })
        )) ?? []
        var byExternalID = Dictionary(uniqueKeysWithValues: existing.compactMap { e -> (String, PersonalEvent)? in
            guard let ext = e.externalID else { return nil }
            return (ext, e)
        })

        var imported = 0
        for ek in events {
            let extID = ek.eventIdentifier ?? UUID().uuidString
            let title = ek.title ?? "(no title)"
            let notes = ek.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            let date = ek.startDate ?? .now
            let allDay = ek.isAllDay
            let source = ek.calendar?.title

            if let existing = byExternalID[extID] {
                existing.title = title
                existing.date = date
                existing.notes = notes?.isEmpty == false ? notes : nil
                existing.isAllDay = allDay
                existing.sourceCalendar = source
            } else {
                let row = PersonalEvent(
                    title: title,
                    date: date,
                    notes: notes?.isEmpty == false ? notes : nil,
                    isAllDay: allDay,
                    externalID: extID,
                    sourceCalendar: source
                )
                context.insert(row)
                byExternalID[extID] = row
                imported += 1
            }
        }
        try? context.save()
        SnapshotStore.publishReminders(from: context)
        WidgetReloader.reloadReminderWidgets()
        return imported
    }

    private func colorInt(_ cg: CGColor?) -> Int {
        guard let cg, let components = cg.components, components.count >= 3 else { return 0x888888 }
        let r = Int(components[0] * 255) & 0xff
        let g = Int(components[1] * 255) & 0xff
        let b = Int(components[2] * 255) & 0xff
        return (r << 16) | (g << 8) | b
    }
}
