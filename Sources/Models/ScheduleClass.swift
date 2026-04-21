import Foundation
import SwiftData

@Model
final class ScheduleClass {
    var id: UUID
    var name: String
    var room: String?
    var teacher: String?
    var daysOfWeek: [Int]        // ISO: 1=Mon ... 7=Sun
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var kindRaw: String          // "academic" | "lunch"
    var sortKey: Int             // sort helper — earliest day × 10000 + h*100 + m
    var periodKey: String?       // "A".."G" | "Lunch" | nil for custom entries

    init(
        id: UUID = UUID(),
        name: String,
        room: String? = nil,
        teacher: String? = nil,
        daysOfWeek: [Int],
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        kindRaw: String = "academic",
        periodKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.teacher = teacher
        self.daysOfWeek = daysOfWeek
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.kindRaw = kindRaw
        let firstDay = daysOfWeek.min() ?? 8
        self.sortKey = firstDay * 10000 + startHour * 100 + startMinute
        self.periodKey = periodKey
    }

    var kind: ClassKind {
        get { kindRaw == "lunch" ? .lunch : .academic }
        set { kindRaw = newValue == .lunch ? "lunch" : "academic" }
    }
}

extension ScheduleClass {
    func asClassPeriod() -> ClassPeriod {
        ClassPeriod(
            id: id,
            name: name,
            room: room,
            teacher: teacher,
            daysOfWeek: daysOfWeek,
            startTime: DateComponents(hour: startHour, minute: startMinute),
            endTime: DateComponents(hour: endHour, minute: endMinute),
            kind: kind
        )
    }
}

extension Array where Element == ScheduleClass {
    func asClassPeriods() -> [ClassPeriod] {
        map { $0.asClassPeriod() }
    }
}
