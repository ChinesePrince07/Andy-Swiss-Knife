import Foundation

enum RRuleExpander {
    static func expand(
        event: ICSEvent,
        from windowStart: Date,
        to windowEnd: Date,
        calendar: Calendar = .current
    ) -> [ICSEvent] {
        guard let rrule = event.rrule else {
            if event.end >= windowStart && event.start <= windowEnd {
                return [event]
            }
            return []
        }

        let rules = parseRRule(rrule)
        let freq = rules["FREQ"] ?? ""
        let interval = Int(rules["INTERVAL"] ?? "1") ?? 1
        let count = rules["COUNT"].flatMap(Int.init)
        let untilDate = rules["UNTIL"].flatMap(parseUntil)

        let byDay: [Int] = (rules["BYDAY"] ?? "")
            .split(separator: ",")
            .compactMap { token in
                switch token {
                case "MO": return 2
                case "TU": return 3
                case "WE": return 4
                case "TH": return 5
                case "FR": return 6
                case "SA": return 7
                case "SU": return 1
                default: return nil
                }
            }

        var out: [ICSEvent] = []
        var iter = event.start
        var emitted = 0
        let duration = event.end.timeIntervalSince(event.start)

        let step: Calendar.Component
        switch freq {
        case "DAILY": step = .day
        case "WEEKLY": step = .weekOfYear
        case "MONTHLY": step = .month
        case "YEARLY": step = .year
        default:
            if event.end >= windowStart && event.start <= windowEnd {
                return [event]
            }
            return []
        }

        while iter <= windowEnd {
            if let until = untilDate, iter > until { break }
            if let count, emitted >= count { break }

            let instances = freq == "WEEKLY" && !byDay.isEmpty
                ? expandWeekDays(baseStart: iter, duration: duration, byDay: byDay, calendar: calendar)
                : [(iter, iter.addingTimeInterval(duration))]

            for (s, e) in instances {
                if e < windowStart { continue }
                if s > windowEnd { continue }
                out.append(ICSEvent(
                    uid: "\(event.uid)-\(Int(s.timeIntervalSince1970))",
                    summary: event.summary,
                    description: event.description,
                    start: s,
                    end: e,
                    location: event.location,
                    isAllDay: event.isAllDay,
                    rrule: nil
                ))
                emitted += 1
                if let count, emitted >= count { break }
            }

            guard let next = calendar.date(byAdding: step, value: interval, to: iter) else { break }
            iter = next
        }

        return out
    }

    private static func expandWeekDays(
        baseStart: Date,
        duration: TimeInterval,
        byDay: [Int],
        calendar: Calendar
    ) -> [(Date, Date)] {
        var out: [(Date, Date)] = []
        let baseWeekday = calendar.component(.weekday, from: baseStart)
        for target in byDay {
            let delta = ((target - baseWeekday) + 7) % 7
            if let day = calendar.date(byAdding: .day, value: delta, to: baseStart) {
                out.append((day, day.addingTimeInterval(duration)))
            }
        }
        return out
    }

    private static func parseRRule(_ rule: String) -> [String: String] {
        var dict: [String: String] = [:]
        for part in rule.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                dict[String(kv[0])] = String(kv[1])
            }
        }
        return dict
    }

    private static func parseUntil(_ raw: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyyMMdd'T'HHmmss'Z'", "yyyyMMdd"] {
            df.dateFormat = fmt
            if let d = df.date(from: raw) { return d }
        }
        return nil
    }
}
