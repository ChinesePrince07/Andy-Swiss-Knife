import Foundation

enum Config {
    @MainActor
    static var canvasFeedURL: URL? {
        let user = UserSettings.shared.canvasFeedURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, let url = URL(string: user) else { return nil }
        return url
    }

    static let diningURL = URL(string: "https://www.suffieldacademy.org/suffieldfamilies/apppost")!
    static let eventsICSURL = URL(string: "https://www.suffieldacademy.org/calendar/calendar_352.ics")!
}
