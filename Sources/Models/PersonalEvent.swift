import Foundation
import SwiftData

@Model
final class PersonalEvent {
    var id: UUID
    var title: String
    var date: Date
    var notes: String?
    var notificationID: String?
    var isAllDay: Bool
    var createdAt: Date
    var externalID: String?    // EKEvent.eventIdentifier when imported from Apple Calendar
    var sourceCalendar: String?
    var sortOrder: Double?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        notes: String? = nil,
        notificationID: String? = nil,
        isAllDay: Bool = false,
        createdAt: Date = .now,
        externalID: String? = nil,
        sourceCalendar: String? = nil,
        sortOrder: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.notes = notes
        self.notificationID = notificationID
        self.isAllDay = isAllDay
        self.createdAt = createdAt
        self.externalID = externalID
        self.sourceCalendar = sourceCalendar
        self.sortOrder = sortOrder
    }
}
