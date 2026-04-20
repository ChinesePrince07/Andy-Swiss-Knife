import Foundation
import Observation

@Observable
@MainActor
final class UserSettings {
    static let shared = UserSettings()
    private static let nameKey = "user.displayName"

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Self.nameKey) }
    }

    private init() {
        self.displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? "Andy"
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
