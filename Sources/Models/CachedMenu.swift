import Foundation
import SwiftData

@Model
final class CachedMenu {
    @Attribute(.unique) var dateKey: String
    var fetchedAt: Date
    var breakfast: String
    var lunch: String
    var dinner: String

    init(
        dateKey: String,
        fetchedAt: Date = .now,
        breakfast: String = "",
        lunch: String = "",
        dinner: String = ""
    ) {
        self.dateKey = dateKey
        self.fetchedAt = fetchedAt
        self.breakfast = breakfast
        self.lunch = lunch
        self.dinner = dinner
    }

    var isEmpty: Bool {
        breakfast.isEmpty && lunch.isEmpty && dinner.isEmpty
    }
}
