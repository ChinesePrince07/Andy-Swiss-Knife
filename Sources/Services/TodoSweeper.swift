import Foundation
import SwiftData

@MainActor
final class TodoSweeper {
    static let retention: TimeInterval = 60 * 60   // 1 hour

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Deletes completed manual todos whose completedAt is older than retention.
    /// Canvas items are never auto-deleted (externalID != nil).
    func sweep(now: Date = .now) {
        let cutoff = now.addingTimeInterval(-Self.retention)
        let predicate = #Predicate<Todo> {
            $0.isDone == true
            && $0.externalID == nil
            && $0.completedAt != nil
        }
        guard let todos = try? context.fetch(FetchDescriptor<Todo>(predicate: predicate)) else {
            return
        }
        var deleted = false
        for t in todos {
            if let c = t.completedAt, c < cutoff {
                context.delete(t)
                deleted = true
            }
        }
        if deleted { try? context.save() }
    }
}
