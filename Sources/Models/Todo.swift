import Foundation
import SwiftData

enum TodoSource: String, Codable {
    case manual
    case canvas
}

@Model
final class Todo {
    var id: UUID
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var createdAt: Date
    var notificationID: String?
    var source: TodoSource
    var externalID: String?
    var userEdited: Bool

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = .now,
        notificationID: String? = nil,
        source: TodoSource = .manual,
        externalID: String? = nil,
        userEdited: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.notificationID = notificationID
        self.source = source
        self.externalID = externalID
        self.userEdited = userEdited
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate < .now
    }
}
