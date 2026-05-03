import Foundation
import Observation

@Observable
final class DriveAdmin {
    @MainActor static let shared = DriveAdmin()

    var isAdmin = false
    private let passwordKey = "files.adminPassword"

    var hasCustomPassword: Bool {
        UserDefaults.standard.string(forKey: passwordKey) != nil
    }

    private var storedPassword: String {
        UserDefaults.standard.string(forKey: passwordKey) ?? "admin"
    }

    @discardableResult
    func login(password: String) -> Bool {
        guard password == storedPassword else { return false }
        isAdmin = true
        return true
    }

    func logout() { isAdmin = false }

    func setPassword(_ newPassword: String) {
        UserDefaults.standard.set(newPassword, forKey: passwordKey)
    }
}

// MARK: - Starred files (local, WebDAV has no native star)

extension UserDefaults {
    private static let starKey = "drive.starred"

    func isStarred(path: String) -> Bool {
        ((array(forKey: Self.starKey) as? [String]) ?? []).contains(path)
    }

    func toggleStar(path: String) {
        var list = (array(forKey: Self.starKey) as? [String]) ?? []
        if let idx = list.firstIndex(of: path) { list.remove(at: idx) } else { list.append(path) }
        set(list, forKey: Self.starKey)
    }
}
