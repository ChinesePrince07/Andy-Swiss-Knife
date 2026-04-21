import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetReloader {
    static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func reloadMenuWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "MenuWidget")
        #endif
    }

    static func reloadTodoWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
        #endif
    }

    static func reloadReminderWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "ReminderWidget")
        #endif
    }
}
