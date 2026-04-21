import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(phaseLabel(context.state.phase))
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(1.0)
                        .foregroundStyle(.secondary)
                    Text(timerInterval: timerRange(context: context), countsDown: true)
                        .monospacedDigit()
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                }
                Spacer()
                ProgressView(
                    timerInterval: timerRange(context: context),
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.circular)
                .tint(.primary)
                .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color.black.opacity(0.15))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: timerRange(context: context), countsDown: true)
                        .monospacedDigit()
                        .font(.system(.title2, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(phaseLabel(context.state.phase))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: timerRange(context: context), countsDown: true)
                    .monospacedDigit()
                    .font(.caption)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func phaseLabel(_ p: String) -> String {
        switch p {
        case "focus": return "FOCUS"
        case "break": return "BREAK"
        case "paused": return "PAUSED"
        default: return "POMODORO"
        }
    }

    private func timerRange(context: ActivityViewContext<PomodoroAttributes>) -> ClosedRange<Date> {
        let start = context.state.endDate.addingTimeInterval(TimeInterval(-context.state.phaseLength))
        return start...context.state.endDate
    }
}
