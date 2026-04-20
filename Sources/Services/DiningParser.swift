import Foundation

struct DiningParseResult: Equatable {
    var breakfast: String
    var lunch: String
    var dinner: String
}

enum DiningParser {
    static func parseToday(html: String, weekday: String) throws -> DiningParseResult {
        let text = stripHTML(html)

        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard let todayIdx = weekdays.firstIndex(of: weekday) else {
            throw DiningServiceError.parseFailed
        }

        let todaySection = sectionStarting(with: weekday, in: text, upTo: weekdays.filter { $0 != weekday })
        guard !todaySection.isEmpty else { throw DiningServiceError.parseFailed }
        _ = todayIdx

        return DiningParseResult(
            breakfast: extractMeal(named: "Breakfast", in: todaySection),
            lunch: extractMeal(namedOneOf: ["Brunch", "Lunch"], in: todaySection),
            dinner: extractMeal(named: "Dinner", in: todaySection)
        )
    }

    static func stripHTML(_ html: String) -> String {
        var out = html
        out = out.replacingOccurrences(
            of: "<style[^>]*>.*?</style>",
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        out = out.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        out = out.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        out = out.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        out = out.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        out = out.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        out = out.replacingOccurrences(of: "</h[1-6]>", with: "\n", options: .regularExpression)
        out = out.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: "&nbsp;", with: " ")
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        out = out.replacingOccurrences(of: "&#8211;", with: "–")
        out = out.replacingOccurrences(of: "&#8212;", with: "—")
        out = out.replacingOccurrences(of: "&#8217;", with: "’")
        out = out.replacingOccurrences(of: "&rsquo;", with: "’")
        out = out.replacingOccurrences(of: "&ldquo;", with: "“")
        out = out.replacingOccurrences(of: "&rdquo;", with: "”")
        return collapseWhitespace(out)
    }

    private static func collapseWhitespace(_ s: String) -> String {
        let lines = s.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    private static func sectionStarting(with day: String, in text: String, upTo others: [String]) -> String {
        guard let startRange = findHeading(for: day, in: text) else { return "" }
        let tail = String(text[startRange.upperBound...])

        var cut = tail.endIndex
        for other in others {
            if let r = findHeading(for: other, in: tail), r.lowerBound < cut {
                cut = r.lowerBound
            }
        }
        return String(tail[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func findHeading(for day: String, in text: String) -> Range<String.Index>? {
        let pattern = "(^|\\n)\\s*\(day)\\b"
        guard let r = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        return r
    }

    private static func extractMeal(named label: String, in section: String) -> String {
        extractMeal(namedOneOf: [label], in: section)
    }

    private static func extractMeal(namedOneOf labels: [String], in section: String) -> String {
        let allMeals = ["Breakfast", "Brunch", "Lunch", "Dinner"]
        for label in labels {
            guard let start = findHeading(for: label, in: section) else { continue }
            let tail = String(section[start.upperBound...])
            var cut = tail.endIndex
            for other in allMeals where !labels.contains(other) {
                if let r = findHeading(for: other, in: tail), r.lowerBound < cut {
                    cut = r.lowerBound
                }
            }
            return String(tail[..<cut])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
}
