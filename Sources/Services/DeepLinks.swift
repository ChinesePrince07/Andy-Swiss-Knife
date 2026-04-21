import Foundation
import Observation

@Observable
@MainActor
final class DeepLinks {
    static let shared = DeepLinks()

    enum PendingAction: Equatable {
        case addTodo
        case addReminder
    }

    var pendingAction: PendingAction?

    static let urlScheme = "swissknife"

    static func url(for action: PendingAction) -> URL {
        switch action {
        case .addTodo: return URL(string: "\(urlScheme)://add-todo")!
        case .addReminder: return URL(string: "\(urlScheme)://add-reminder")!
        }
    }

    func handle(_ url: URL) {
        guard url.scheme == Self.urlScheme else { return }
        switch url.host {
        case "add-todo": pendingAction = .addTodo
        case "add-reminder": pendingAction = .addReminder
        default: break
        }
    }

    func clear() {
        pendingAction = nil
    }
}
