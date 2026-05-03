import Foundation
import Observation

@Observable
@MainActor
final class UserSettings {
    static let shared = UserSettings()
    private static let nameKey = "user.displayName"
    private static let canvasKey = "user.canvasFeedURL"
    private static let tabsKey = "user.enabledTabs"

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Self.nameKey) }
    }

    var canvasFeedURL: String {
        didSet { UserDefaults.standard.set(canvasFeedURL, forKey: Self.canvasKey) }
    }

    var enabledTabs: [AppTab] {
        didSet { saveTabs() }
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
        self.enabledTabs = Self.loadTabs()
    }

    private static func loadTabs() -> [AppTab] {
        guard let data = UserDefaults.standard.data(forKey: tabsKey),
              let tabs = try? JSONDecoder().decode([AppTab].self, from: data),
              !tabs.isEmpty else {
            return AppTab.allDefault
        }
        return tabs
    }

    private func saveTabs() {
        if let data = try? JSONEncoder().encode(enabledTabs) {
            UserDefaults.standard.set(data, forKey: Self.tabsKey)
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
