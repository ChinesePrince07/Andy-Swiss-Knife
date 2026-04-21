import Foundation
import SwiftData

enum AppModelContainer {
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Todo.self,
            CachedMenu.self,
            CachedEvent.self,
            PersonalEvent.self,
            ScheduleClass.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
