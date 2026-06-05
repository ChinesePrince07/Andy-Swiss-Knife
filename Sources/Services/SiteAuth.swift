import Foundation
import Observation

@Observable
@MainActor
final class SiteAuth {
    static let shared = SiteAuth()

    private static let baseKey = "publishing.siteBaseURL"
    private static let secretKey = "publishing.publishSecret"
    private static let defaultBase = "https://www.andypandy.org"

    var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: Self.baseKey)
            refreshIsAuthed()
        }
    }

    var secret: String {
        didSet {
            if secret.isEmpty {
                KeychainStore.remove(Self.secretKey)
            } else {
                KeychainStore.set(secret, for: Self.secretKey)
            }
            refreshIsAuthed()
        }
    }

    private(set) var isAuthed: Bool = false

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.baseKey) ?? Self.defaultBase
        // Migration: bare host redirected to www on andypandy.org and dropped the
        // Authorization header on iOS. Bump anyone still on the old default.
        let migrated = stored == "https://andypandy.org" ? Self.defaultBase : stored
        self.baseURL = migrated
        if migrated != stored {
            UserDefaults.standard.set(migrated, forKey: Self.baseKey)
        }
        self.secret = KeychainStore.get(Self.secretKey) ?? ""
        refreshIsAuthed()
    }

    func clear() {
        secret = ""
    }

    var endpointURL: URL? {
        URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func refreshIsAuthed() {
        isAuthed = endpointURL != nil && !secret.isEmpty
    }
}
