import Foundation

enum Config {
    @MainActor
    static var canvasFeedURL: URL? {
        let user = UserSettings.shared.canvasFeedURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !user.isEmpty, let url = URL(string: user) { return url }
        let fallback = Secrets.canvasFeedURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty, let url = URL(string: fallback) { return url }
        return nil
    }

    static let diningURL = URL(string: "https://www.suffieldacademy.org/suffieldfamilies/apppost")!
    static let eventsICSURL = URL(string: "https://www.suffieldacademy.org/calendar/calendar_352.ics")!
}
