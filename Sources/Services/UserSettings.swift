import Foundation
import Observation

@Observable
@MainActor
final class UserSettings {
    static let shared = UserSettings()
    private static let nameKey = "user.displayName"
    private static let canvasKey = "user.canvasFeedURL"

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Self.nameKey) }
    }

    var canvasFeedURL: String {
        didSet { UserDefaults.standard.set(canvasFeedURL, forKey: Self.canvasKey) }
    }

    private init() {
        self.displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? "Andy"
        let stored = UserDefaults.standard.string(forKey: Self.canvasKey)
        let seededKey = "user.canvasFeedURL.seeded"
        let didSeed = UserDefaults.standard.bool(forKey: seededKey)
        if let stored, !stored.isEmpty {
            self.canvasFeedURL = stored
        } else if !didSeed {
            let seed = Secrets.canvasFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
            self.canvasFeedURL = seed
            UserDefaults.standard.set(seed, forKey: Self.canvasKey)
            UserDefaults.standard.set(true, forKey: seededKey)
        } else {
            self.canvasFeedURL = ""
        }
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
