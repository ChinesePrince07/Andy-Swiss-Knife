import Foundation

struct Meal: Hashable, Sendable {
    let dateKey: String
    let breakfast: String
    let lunch: String
    let dinner: String
    let fetchedAt: Date

    var hasContent: Bool {
        !breakfast.isEmpty || !lunch.isEmpty || !dinner.isEmpty
    }
}

struct Event: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?

    var isAllDay: Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: start)
        return comps.hour == 0 && comps.minute == 0 && comps.second == 0
            && Calendar.current.isDate(start, inSameDayAs: end)
    }
}
