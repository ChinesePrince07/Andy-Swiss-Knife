import Foundation
import Observation

@Observable
@MainActor
final class UserSettings {
    static let shared = UserSettings()
    private static let nameKey = "user.displayName"
    private static let canvasKey = "user.canvasFeedURL"
    private static let pomodoroKey = "user.pomodoroEnabled"

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Self.nameKey) }
    }

    var canvasFeedURL: String {
        didSet { UserDefaults.standard.set(canvasFeedURL, forKey: Self.canvasKey) }
    }

    var pomodoroEnabled: Bool {
        didSet { UserDefaults.standard.set(pomodoroEnabled, forKey: Self.pomodoroKey) }
    }

    private init() {
        self.displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? "Andy"
        self.canvasFeedURL = UserDefaults.standard.string(forKey: Self.canvasKey) ?? ""
        self.pomodoroEnabled = UserDefaults.standard.object(forKey: Self.pomodoroKey) as? Bool ?? false
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
