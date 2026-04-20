import SwiftUI

struct PomodoroView: View {
    let timer: PomodoroTimer
    let services: Services

    init(services: Services) {
        self.services = services
        self.timer = services.pomodoro
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text(phaseLabel)
                .font(AppType.sectionLabel)
                .kerning(1.5)
                .foregroundStyle(AppColors.secondary)

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = timer.remainingSeconds
                ZStack {
                    Circle()
                        .stroke(AppColors.hairline, lineWidth: 0.5)
                        .frame(width: 260, height: 260)

                    Circle()
                        .trim(from: 0, to: progress(remaining: remaining))
                        .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 0.5, lineCap: .butt))
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))

                    Text(formatted(seconds: remaining))
                        .font(AppType.mono)
                        .foregroundStyle(AppColors.primary)
                }
            }

            HStack(spacing: 24) {
                Button {
                    primaryAction()
                } label: {
                    Text(primaryButtonLabel)
                        .font(AppType.bodyMedium)
                        .foregroundStyle(AppColors.primary)
                        .frame(minWidth: 120)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().stroke(AppColors.primary, lineWidth: 0.5))
                }

                if timer.phase != .idle {
                    Button {
                        timer.reset()
                    } label: {
                        Text("Reset")
                            .font(AppType.body)
                            .foregroundStyle(AppColors.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(ThemedBackground())
        .navigationTitle("Pomodoro")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var phaseLabel: String {
        switch timer.phase {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        case .paused: return "Paused"
        }
    }

    private func progress(remaining: Int) -> Double {
        let total: Int
        switch timer.phase {
        case .idle: total = PomodoroTimer.focusLengthSeconds
        case .paused: total = timer.phaseLength > 0 ? timer.phaseLength : PomodoroTimer.focusLengthSeconds
        case .focus: total = PomodoroTimer.focusLengthSeconds
        case .shortBreak: total = PomodoroTimer.breakLengthSeconds
        }
        let elapsed = max(0, total - remaining)
        return total == 0 ? 0 : Double(elapsed) / Double(total)
    }

    private var primaryButtonLabel: String {
        switch timer.phase {
        case .idle: return "Start 25"
        case .focus: return "Pause"
        case .shortBreak: return "Pause"
        case .paused: return "Resume"
        }
    }

    private func primaryAction() {
        switch timer.phase {
        case .idle, .paused: timer.start()
        case .focus, .shortBreak: timer.pause()
        }
    }

    private func formatted(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
