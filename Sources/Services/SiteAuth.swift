import Foundation
import Observation

@Observable
@MainActor
final class SiteAuth {
    static let shared = SiteAuth()

    private static let baseKey = "publishing.siteBaseURL"
    private static let secretKey = "publishing.publishSecret"
    private static let defaultBase = "https://andypandy.org"

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
        self.baseURL = UserDefaults.standard.string(forKey: Self.baseKey) ?? Self.defaultBase
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
