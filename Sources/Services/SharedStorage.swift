import Foundation

enum SharedStorage {
    static let appGroupID = "group.com.andyzhang.AndySwissKnife"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var modelStoreURL: URL? {
        containerURL?.appendingPathComponent("SwissKnife.sqlite")
    }

    // Keys for shared UserDefaults
    enum Keys {
        static let menu = "shared.menu"       // JSON-encoded Meal
        static let lastMenuUpdate = "shared.lastMenuUpdate"
    }
}
