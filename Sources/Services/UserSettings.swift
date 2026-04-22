import Foundation
import Observation

@Observable
@MainActor
final class UserSettings {
    static let shared = UserSettings()
    private static let nameKey = "user.displayName"
    private static let canvasKey = "user.canvasFeedURL"
    private static let athleticsKey = "user.athleticsFeedURL"

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Self.nameKey) }
    }

    var canvasFeedURL: String {
        didSet { UserDefaults.standard.set(canvasFeedURL, forKey: Self.canvasKey) }
    }

    var athleticsFeedURL: String {
        didSet { UserDefaults.standard.set(athleticsFeedURL, forKey: Self.athleticsKey) }
    }

    private init() {
        self.displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? "Andy"
        self.canvasFeedURL = UserDefaults.standard.string(forKey: Self.canvasKey) ?? ""
        self.athleticsFeedURL = UserDefaults.standard.string(forKey: Self.athleticsKey) ?? ""
    }

    func greeting(for date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good night"
        }
    }
}
