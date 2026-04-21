import Foundation

/// Suffield Academy fall schedule — 7 lettered periods rotating across
/// Mon-Sat. Each period has a fixed set of day/time slots. Lunch blocks
/// are also fixed. Users pick a course name / room / teacher for each
/// period; the time grid stays the same.
struct SuffieldSlot: Hashable {
    let day: Int          // ISO weekday 1=Mon ... 7=Sun
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
}

struct SuffieldPeriod: Identifiable, Hashable {
    let letter: String    // "A", "B", ..., or "Lunch"
    let kind: ClassKind
    let slots: [SuffieldSlot]
    var id: String { letter }
}

enum SuffieldTemplate {
    static let periods: [SuffieldPeriod] = [
        SuffieldPeriod(letter: "A", kind: .academic, slots: [
            SuffieldSlot(day: 1, startHour: 8, startMinute: 20, endHour: 9, endMinute: 5),
            SuffieldSlot(day: 2, startHour: 9, startMinute: 10, endHour: 10, endMinute: 15),
            SuffieldSlot(day: 4, startHour: 8, startMinute: 20, endHour: 9, endMinute: 5),
            SuffieldSlot(day: 5, startHour: 9, startMinute: 10, endHour: 10, endMinute: 15)
        ]),
        SuffieldPeriod(letter: "B", kind: .academic, slots: [
            SuffieldSlot(day: 1, startHour: 9, startMinute: 10, endHour: 10, endMinute: 15),
            SuffieldSlot(day: 2, startHour: 8, startMinute: 20, endHour: 9, endMinute: 5),
            SuffieldSlot(day: 4, startHour: 9, startMinute: 10, endHour: 10, endMinute: 15),
            SuffieldSlot(day: 5, startHour: 8, startMinute: 20, endHour: 9, endMinute: 5)
        ]),
        SuffieldPeriod(letter: "C", kind: .academic, slots: [
            SuffieldSlot(day: 1, startHour: 11, startMinute: 10, endHour: 12, endMinute: 15),
            SuffieldSlot(day: 3, startHour: 9, startMinute: 30, endHour: 10, endMinute: 15),
            SuffieldSlot(day: 4, startHour: 13, startMinute: 5, endHour: 14, endMinute: 10),
            SuffieldSlot(day: 6, startHour: 9, startMinute: 30, endHour: 10, endMinute: 15)
        ]),
        SuffieldPeriod(letter: "D", kind: .academic, slots: [
            SuffieldSlot(day: 2, startHour: 13, startMinute: 5, endHour: 13, endMinute: 50),
            SuffieldSlot(day: 3, startHour: 8, startMinute: 20, endHour: 9, endMinute: 25),
            SuffieldSlot(day: 5, startHour: 13, startMinute: 55, endHour: 14, endMinute: 40),
            SuffieldSlot(day: 6, startHour: 10, startMinute: 20, endHour: 11, endMinute: 25)
        ]),
        SuffieldPeriod(letter: "E", kind: .academic, slots: [
            SuffieldSlot(day: 1, startHour: 10, startMinute: 20, endHour: 11, endMinute: 5),
            SuffieldSlot(day: 2, startHour: 11, startMinute: 10, endHour: 12, endMinute: 15),
            SuffieldSlot(day: 4, startHour: 10, startMinute: 20, endHour: 11, endMinute: 5),
            SuffieldSlot(day: 5, startHour: 11, startMinute: 10, endHour: 12, endMinute: 15)
        ]),
        SuffieldPeriod(letter: "F", kind: .academic, slots: [
            SuffieldSlot(day: 2, startHour: 13, startMinute: 55, endHour: 14, endMinute: 40),
            SuffieldSlot(day: 3, startHour: 10, startMinute: 20, endHour: 11, endMinute: 25),
            SuffieldSlot(day: 5, startHour: 10, startMinute: 20, endHour: 11, endMinute: 5),
            SuffieldSlot(day: 6, startHour: 8, startMinute: 20, endHour: 9, endMinute: 25)
        ]),
        SuffieldPeriod(letter: "G", kind: .academic, slots: [
            SuffieldSlot(day: 1, startHour: 14, startMinute: 0, endHour: 15, endMinute: 5),
            SuffieldSlot(day: 2, startHour: 10, startMinute: 20, endHour: 11, endMinute: 5),
            SuffieldSlot(day: 4, startHour: 11, startMinute: 10, endHour: 12, endMinute: 15),
            SuffieldSlot(day: 5, startHour: 13, startMinute: 5, endHour: 13, endMinute: 50)
        ]),
        SuffieldPeriod(letter: "Lunch", kind: .lunch, slots: [
            SuffieldSlot(day: 1, startHour: 12, startMinute: 20, endHour: 13, endMinute: 0),
            SuffieldSlot(day: 2, startHour: 12, startMinute: 20, endHour: 13, endMinute: 0),
            SuffieldSlot(day: 3, startHour: 11, startMinute: 30, endHour: 12, endMinute: 30),
            SuffieldSlot(day: 4, startHour: 12, startMinute: 20, endHour: 13, endMinute: 0),
            SuffieldSlot(day: 5, startHour: 12, startMinute: 20, endHour: 13, endMinute: 0),
            SuffieldSlot(day: 6, startHour: 11, startMinute: 30, endHour: 12, endMinute: 30)
        ])
    ]
}
