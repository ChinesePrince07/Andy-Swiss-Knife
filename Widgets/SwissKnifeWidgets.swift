import WidgetKit
import SwiftUI

@main
struct SwissKnifeWidgets: WidgetBundle {
    var body: some Widget {
        NextClassWidget()
        TodoWidget()
        ReminderWidget()
        MenuWidget()
        #if canImport(ActivityKit)
        PomodoroLiveActivity()
        #endif
    }
}
