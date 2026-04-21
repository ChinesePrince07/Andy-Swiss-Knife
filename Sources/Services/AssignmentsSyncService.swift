import Foundation
import SwiftData

@MainActor
final class AssignmentsSyncService {
    private let http: HTTPClient
    private let context: ModelContext
    private let overrideFeedURL: URL?

    init(http: HTTPClient, context: ModelContext, feedURL: URL? = nil) {
        self.http = http
        self.context = context
        self.overrideFeedURL = feedURL
    }

    func syncCanvas(now: Date = .now) async throws {
        guard let url = overrideFeedURL ?? Config.canvasFeedURL else {
            UserDefaults.standard.set(now, forKey: "lastSync.canvas")
            return
        }

        let data = try await http.data(for: url)
        let source = String(data: data, encoding: .utf8) ?? ""
        let events = try ICSParser.parse(source)

        let existing = try context.fetch(
            FetchDescriptor<Todo>(predicate: #Predicate { $0.externalID != nil })
        )
        var byExternalID: [String: Todo] = [:]
        for t in existing {
            if let ext = t.externalID { byExternalID[ext] = t }
        }

        for e in events {
            if let todo = byExternalID[e.uid] {
                if !todo.userEdited {
                    todo.title = e.summary
                    todo.dueDate = e.end
                    todo.notes = e.description
                }
            } else {
                let todo = Todo(
                    title: e.summary,
                    dueDate: e.end,
                    source: .canvas,
                    externalID: e.uid,
                    notes: e.description
                )
                context.insert(todo)
            }
        }

        try? context.save()
        UserDefaults.standard.set(now, forKey: "lastSync.canvas")
    }
}
