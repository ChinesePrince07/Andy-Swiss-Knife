import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Bridges PomodoroTimer to ActivityKit Live Activity.
/// Safe to call even on simulators / devices without ActivityKit —
/// all ops become no-ops.
@MainActor
enum PomodoroActivity {
    #if canImport(ActivityKit)
    private static var activity: Activity<PomodoroAttributes>?
    #endif

    static func start(phase: String, durationSeconds: Int) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let end = Date().addingTimeInterval(TimeInterval(durationSeconds))
        let state = PomodoroAttributes.ContentState(
            phase: phase, endDate: end, phaseLength: durationSeconds
        )
        do {
            activity = try Activity.request(
                attributes: PomodoroAttributes(label: "Pomodoro"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
        #endif
    }

    static func update(phase: String, durationSeconds: Int) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        let end = Date().addingTimeInterval(TimeInterval(durationSeconds))
        let state = PomodoroAttributes.ContentState(
            phase: phase, endDate: end, phaseLength: durationSeconds
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        #endif
    }

    static func pause(remainingSeconds: Int) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        let end = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let state = PomodoroAttributes.ContentState(
            phase: "paused", endDate: end, phaseLength: remainingSeconds
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        #endif
    }

    static func end() {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }
}
