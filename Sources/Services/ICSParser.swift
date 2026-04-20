import Foundation

enum ICSParserError: Error, Equatable {
    case invalidInput
    case missingRequiredField(String)
}

struct ICSEvent: Hashable, Sendable {
    let uid: String
    let summary: String
    let description: String?
    let start: Date
    let end: Date
    let location: String?
    let isAllDay: Bool
    let rrule: String?
}

enum ICSParser {
    static func parse(_ source: String) throws -> [ICSEvent] {
        let unfolded = unfold(source)
        let lines = unfolded.components(separatedBy: "\n")

        var events: [ICSEvent] = []
        var current: [String: String] = [:]
        var inEvent = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                current = [:]
            } else if trimmed == "END:VEVENT" {
                inEvent = false
                if let event = try? makeEvent(from: current) {
                    events.append(event)
                }
            } else if inEvent, let (key, value) = splitProperty(trimmed) {
                current[key] = value
            }
        }
        return events
    }

    private static func unfold(_ s: String) -> String {
        // Normalize line endings so unfold only has to look for \n.
        // ICS uses CRLF; in Swift, "\r\n" can collapse into a single grapheme,
        // which broke the previous character-by-character scan.
        let normalized = s
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var out = ""
        var i = normalized.startIndex
        while i < normalized.endIndex {
            let c = normalized[i]
            let next = normalized.index(after: i)
            if c == "\n", next < normalized.endIndex,
               (normalized[next] == " " || normalized[next] == "\t") {
                // Drop both the newline and the leading whitespace — merge the line.
                i = normalized.index(after: next)
                continue
            }
            out.append(c)
            i = next
        }
        return out
    }

    private static func splitProperty(_ line: String) -> (String, String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let lhs = String(line[..<colon])
        let rhs = String(line[line.index(after: colon)...])
        return (lhs, rhs)
    }

    private static func makeEvent(from props: [String: String]) throws -> ICSEvent {
        guard let uid = props["UID"] else { throw ICSParserError.missingRequiredField("UID") }
        let summary = unescape(props["SUMMARY"] ?? "")
        let description = props["DESCRIPTION"].map(unescape)
        let location = props["LOCATION"].map(unescape)

        let dtStartRaw = props.first(where: { $0.key.hasPrefix("DTSTART") })
        let dtEndRaw = props.first(where: { $0.key.hasPrefix("DTEND") })
        guard let startKV = dtStartRaw else { throw ICSParserError.missingRequiredField("DTSTART") }

        let (start, startAllDay) = try parseICSDate(key: startKV.key, value: startKV.value)

        let end: Date
        let endAllDay: Bool
        if let endKV = dtEndRaw {
            let (d, a) = try parseICSDate(key: endKV.key, value: endKV.value)
            end = d
            endAllDay = a
        } else {
            end = start
            endAllDay = startAllDay
        }

        return ICSEvent(
            uid: uid,
            summary: summary,
            description: description,
            start: start,
            end: end,
            location: location,
            isAllDay: startAllDay && endAllDay,
            rrule: props["RRULE"]
        )
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\,", with: ",")
         .replacingOccurrences(of: "\\;", with: ";")
         .replacingOccurrences(of: "\\n", with: "\n")
         .replacingOccurrences(of: "\\N", with: "\n")
         .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func parseICSDate(key: String, value: String) throws -> (Date, Bool) {
        let isAllDay = key.contains("VALUE=DATE") && !key.contains("VALUE=DATE-TIME")
        let cleaned = value.trimmingCharacters(in: .whitespaces)

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")

        if isAllDay || cleaned.count == 8 {
            df.dateFormat = "yyyyMMdd"
            if let d = df.date(from: cleaned) { return (d, true) }
        }

        if cleaned.hasSuffix("Z") {
            df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            if let d = df.date(from: cleaned) { return (d, false) }
        }

        if let tzid = extractTZID(from: key) {
            df.timeZone = TimeZone(identifier: tzid) ?? TimeZone(secondsFromGMT: 0)!
            df.dateFormat = "yyyyMMdd'T'HHmmss"
            if let d = df.date(from: cleaned) { return (d, false) }
        }

        df.timeZone = TimeZone.current
        df.dateFormat = "yyyyMMdd'T'HHmmss"
        if let d = df.date(from: cleaned) { return (d, false) }

        throw ICSParserError.invalidInput
    }

    private static func extractTZID(from key: String) -> String? {
        guard let range = key.range(of: "TZID=") else { return nil }
        let rest = key[range.upperBound...]
        return rest.split(separator: ";").first.map(String.init)
    }
}
