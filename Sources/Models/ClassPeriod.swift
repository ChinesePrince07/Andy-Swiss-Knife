import Foundation

struct ClassPeriod: Identifiable, Hashable {
    let id: UUID
    let name: String
    let room: String?
    let teacher: String?
    let daysOfWeek: [Int]
    let startTime: DateComponents
    let endTime: DateComponents

    init(
        id: UUID = UUID(),
        name: String,
        room: String?,
        teacher: String?,
        daysOfWeek: [Int],
        startTime: DateComponents,
        endTime: DateComponents
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.teacher = teacher
        self.daysOfWeek = daysOfWeek
        self.startTime = startTime
        self.endTime = endTime
    }

    func occursOn(weekday: Int) -> Bool {
        daysOfWeek.contains(weekday)
    }

    func startDate(on day: Date, calendar: Calendar = .current) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = startTime.hour
        comps.minute = startTime.minute
        return calendar.date(from: comps)
    }

    func endDate(on day: Date, calendar: Calendar = .current) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = endTime.hour
        comps.minute = endTime.minute
        return calendar.date(from: comps)
    }
}

extension Array where Element == ClassPeriod {
    func today(_ now: Date = .now, calendar: Calendar = .current) -> [ClassPeriod] {
        let iso = isoWeekday(from: now, calendar: calendar)
        return self
            .filter { $0.occursOn(weekday: iso) }
            .sorted {
                ($0.startTime.hour ?? 0, $0.startTime.minute ?? 0) <
                ($1.startTime.hour ?? 0, $1.startTime.minute ?? 0)
            }
    }

    func next(after now: Date = .now, calendar: Calendar = .current) -> (ClassPeriod, Date)? {
        let todays = today(now, calendar: calendar)
        for c in todays {
            if let start = c.startDate(on: now, calendar: calendar), start > now {
                return (c, start)
            }
        }
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let iso = isoWeekday(from: day, calendar: calendar)
            let classes = self
                .filter { $0.occursOn(weekday: iso) }
                .sorted {
                    ($0.startTime.hour ?? 0, $0.startTime.minute ?? 0) <
                    ($1.startTime.hour ?? 0, $1.startTime.minute ?? 0)
                }
            if let first = classes.first, let start = first.startDate(on: day, calendar: calendar) {
                return (first, start)
            }
        }
        return nil
    }
}

func isoWeekday(from date: Date, calendar: Calendar = .current) -> Int {
    let weekday = calendar.component(.weekday, from: date)  // 1=Sun ... 7=Sat
    return weekday == 1 ? 7 : weekday - 1                   // 1=Mon ... 7=Sun
}
