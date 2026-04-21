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

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url = SharedStorage.modelStoreURL {
            config = ModelConfiguration(schema: schema, url: url)
        } else {
            config = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
