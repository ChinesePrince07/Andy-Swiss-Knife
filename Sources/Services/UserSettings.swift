import Foundation
import Observation

@Observable
@MainActor
final class UserSettings {
    static let shared = UserSettings()
    private static let nameKey = "user.displayName"
    private static let canvasKey = "user.canvasFeedURL"
    private static let eventsKey = "user.eventsICSURL"
    private static let tabsKey = "user.enabledTabs"
    private static let onboardingKey = "user.hasCompletedOnboarding.v1"
    private static let badmintonSeededKey = "user.badmintonTabSeeded.v1"
    private static let fitcheckSeededKey = "user.fitcheckTabSeeded.v1"

    var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: Self.nameKey) }
    }

    var canvasFeedURL: String {
        didSet { UserDefaults.standard.set(canvasFeedURL, forKey: Self.canvasKey) }
    }

    var eventsICSURL: String {
        didSet { UserDefaults.standard.set(eventsICSURL, forKey: Self.eventsKey) }
    }

    var enabledTabs: [AppTab] {
        didSet { saveTabs() }
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    private init() {
        self.displayName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        self.canvasFeedURL = UserDefaults.standard.string(forKey: Self.canvasKey) ?? ""
        self.eventsICSURL = UserDefaults.standard.string(forKey: Self.eventsKey) ?? ""
        self.enabledTabs = Self.loadTabs()
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        seedBadmintonTabIfNeeded()
        seedFitCheckTabIfNeeded()
    }

    /// One-time: surface the new FitCheck tab for existing installs.
    private func seedFitCheckTabIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.fitcheckSeededKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.fitcheckSeededKey)
        if !enabledTabs.contains(.fitcheck) {
            enabledTabs.append(.fitcheck)   // didSet persists
        }
    }

    /// One-time: surface the new Badminton tab for existing installs (so it's a
    /// real tab out of the box, not something to hunt for in tab settings).
    private func seedBadmintonTabIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.badmintonSeededKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.badmintonSeededKey)
        if !enabledTabs.contains(.badminton) {
            enabledTabs.append(.badminton)   // didSet persists
        }
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
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
