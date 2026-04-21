import Foundation
import AppIntents
import SwiftData

struct ToggleTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Todo"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Todo ID") var todoID: String

    init() {}
    init(todoID: String) { self.todoID = todoID }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: todoID) else { return .result() }
        let container = try AppModelContainer.make()
        let context = container.mainContext
        let predicate = #Predicate<Todo> { $0.id == uuid }
        if let todo = try context.fetch(FetchDescriptor<Todo>(predicate: predicate)).first {
            todo.isDone.toggle()
            todo.completedAt = todo.isDone ? .now : nil
            try? context.save()
        }
        WidgetReloader.reloadTodoWidgets()
        return .result()
    }
}
