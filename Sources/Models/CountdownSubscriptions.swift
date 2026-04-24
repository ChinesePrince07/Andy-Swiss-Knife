import Foundation
import SwiftData

@MainActor
enum CountdownSubscriptions {
    private static let key = "countdown.selectedEventIDs.v1"
    private static let namesKey = "countdown.customNames.v1"

    static var selectedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    static func isSelected(_ id: String) -> Bool { selectedIDs.contains(id) }

    static func set(_ id: String, selected: Bool) {
        var ids = selectedIDs
        if selected { ids.insert(id) } else { ids.remove(id) }
        selectedIDs = ids
    }

    static func customName(for id: String) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String] ?? [:]
        let val = map[id]
        return (val?.isEmpty ?? true) ? nil : val
    }

    static func setCustomName(_ name: String?, for id: String) {
        var map = UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String] ?? [:]
        map[id] = name
        UserDefaults.standard.set(map, forKey: namesKey)
    }

    static func displayName(for event: CachedEvent) -> String {
        customName(for: event.id) ?? event.title
    }

    static func nextUpcoming(from context: ModelContext, now: Date = .now) -> CachedEvent? {
        let ids = Array(selectedIDs)
        guard !ids.isEmpty else { return nil }
        let descriptor = FetchDescriptor<CachedEvent>(
            sortBy: [SortDescriptor(\CachedEvent.start)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.first { event in
            ids.contains(event.id) && event.start >= now
        }
    }

    static func allSelected(from context: ModelContext) -> [CachedEvent] {
        let ids = selectedIDs
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<CachedEvent>(
            sortBy: [SortDescriptor(\CachedEvent.start)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { ids.contains($0.id) }
    }
}
