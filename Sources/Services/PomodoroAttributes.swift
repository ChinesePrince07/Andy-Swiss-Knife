import Foundation
#if canImport(ActivityKit)
import ActivityKit

struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: String        // "focus" | "break" | "paused"
        var endDate: Date        // when phase ends (for progress)
        var phaseLength: Int     // total seconds
    }
    var label: String            // "Focus" fallback
}
#endif
