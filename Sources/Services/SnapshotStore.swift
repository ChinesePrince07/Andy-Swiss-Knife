import Foundation
import SwiftData

// JSON snapshots for widgets. Widget targets read these from shared
// UserDefaults; we publish them from the app whenever data changes.

struct TodoSnapshotDTO: Codable, Identifiable {
    let id: UUID
    let title: String
    let isDone: Bool
    let dueDate: Date?
    let createdAt: Date
}

struct ReminderSnapshotDTO: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let isAllDay: Bool
    let notes: String?
}

enum SnapshotStore {
    private static let todosKey = "shared.todos.v1"
    private static let remindersKey = "shared.reminders.v1"

    // MARK: - Read (used by widgets)

    static func readTodos() -> [TodoSnapshotDTO] {
        guard let data = SharedStorage.defaults.data(forKey: todosKey) else { return [] }
        return (try? JSONDecoder().decode([TodoSnapshotDTO].self, from: data)) ?? []
    }

    static func readReminders() -> [ReminderSnapshotDTO] {
        guard let data = SharedStorage.defaults.data(forKey: remindersKey) else { return [] }
        return (try? JSONDecoder().decode([ReminderSnapshotDTO].self, from: data)) ?? []
    }

    // MARK: - Write (app side)

    @MainActor
    static func publishTodos(from context: ModelContext) {
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate { $0.externalID == nil }
        )
        let todos = (try? context.fetch(descriptor)) ?? []
        let snapshots = todos.map {
            TodoSnapshotDTO(
                id: $0.id,
                title: $0.title,
                isDone: $0.isDone,
                dueDate: $0.dueDate,
                createdAt: $0.createdAt
            )
        }
        if let data = try? JSONEncoder().encode(snapshots) {
            SharedStorage.defaults.set(data, forKey: todosKey)
        }
    }

    @MainActor
    static func publishReminders(from context: ModelContext) {
        let descriptor = FetchDescriptor<PersonalEvent>(
            sortBy: [SortDescriptor(\.date)]
        )
        let events = (try? context.fetch(descriptor)) ?? []
        let snapshots = events.map {
            ReminderSnapshotDTO(
                id: $0.id,
                title: $0.title,
                date: $0.date,
                isAllDay: $0.isAllDay,
                notes: $0.notes
            )
        }
        if let data = try? JSONEncoder().encode(snapshots) {
            SharedStorage.defaults.set(data, forKey: remindersKey)
        }
    }
}
