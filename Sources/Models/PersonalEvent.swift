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

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        notes: String? = nil,
        notificationID: String? = nil,
        isAllDay: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.notes = notes
        self.notificationID = notificationID
        self.isAllDay = isAllDay
        self.createdAt = createdAt
    }
}
