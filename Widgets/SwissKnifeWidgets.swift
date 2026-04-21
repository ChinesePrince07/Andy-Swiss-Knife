import WidgetKit
import SwiftUI

@main
struct SwissKnifeWidgets: WidgetBundle {
    var body: some Widget {
        NextClassWidget()
        #if canImport(ActivityKit)
        PomodoroLiveActivity()
        #endif
    }
}
