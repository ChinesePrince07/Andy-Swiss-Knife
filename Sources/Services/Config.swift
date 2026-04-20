import Foundation

enum Config {
    static var canvasFeedURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CANVAS_FEED_URL") as? String,
              !raw.contains("REPLACE_WITH_YOUR_TOKEN"),
              let url = URL(string: raw)
        else { return nil }
        return url
    }

    static let diningURL = URL(string: "https://www.suffieldacademy.org/suffieldfamilies/apppost")!
    static let eventsICSURL = URL(string: "https://www.suffieldacademy.org/calendar/calendar_352.ics")!
}
