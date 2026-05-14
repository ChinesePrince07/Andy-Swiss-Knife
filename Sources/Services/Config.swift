import Foundation

enum Config {
    @MainActor
    static var canvasFeedURL: URL? {
        let user = UserSettings.shared.canvasFeedURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, let url = URL(string: user) else { return nil }
        return url
    }

    @MainActor
    static var eventsICSURL: URL? {
        let user = UserSettings.shared.eventsICSURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, let url = URL(string: user) else { return nil }
        return url
    }

    static let diningURL = URL(string: "https://www.suffieldacademy.org/suffieldfamilies/apppost")!
}
