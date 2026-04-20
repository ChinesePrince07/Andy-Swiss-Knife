import Foundation

enum Config {
    static var canvasFeedURL: URL? {
        let raw = Secrets.canvasFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw) else { return nil }
        return url
    }

    static let diningURL = URL(string: "https://www.suffieldacademy.org/suffieldfamilies/apppost")!
    static let eventsICSURL = URL(string: "https://www.suffieldacademy.org/calendar/calendar_352.ics")!
}
