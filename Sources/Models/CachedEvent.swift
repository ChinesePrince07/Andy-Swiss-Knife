import Foundation
import SwiftData

@Model
final class CachedEvent {
    @Attribute(.unique) var id: String
    var title: String
    var start: Date
    var end: Date
    var location: String?

    init(id: String, title: String, start: Date, end: Date, location: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.location = location
    }
}
