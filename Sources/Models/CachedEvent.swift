import Foundation
import SwiftData

@Model
final class CachedEvent {
    // Stored as "<source>:<uid>" to keep globally unique across overlapping
    // feeds (e.g., two athletic teams sharing a joint event).
    @Attribute(.unique) var id: String
    var title: String
    var start: Date
    var end: Date
    var location: String?
    var source: String?        // "school" (ICS) | "apple-cal-<calendarID>" | nil (legacy)
    var calendarTitle: String?

    init(
        id: String, title: String, start: Date, end: Date,
        location: String? = nil,
        source: String? = nil,
        calendarTitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.source = source
        self.calendarTitle = calendarTitle
    }
}
