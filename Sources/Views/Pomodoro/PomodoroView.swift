import SwiftUI

struct PomodoroView: View {
    let timer: PomodoroTimer
    let services: Services

    init(services: Services) {
        self.services = services
        self.timer = services.pomodoro
    }

    var body: some View {
        ZStack {
            ThemedBackground()
            content
        }
        .navigationTitle("Pomodoro")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(phaseLabel)
                .font(AppType.sectionLabel)
                .kerning(1.5)
                .foregroundStyle(AppColors.secondary)
                .padding(.bottom, 16)

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = timer.remainingSeconds
                let pct = progress(remaining: remaining)
                VStack(spacing: 24) {
                    Text(formatted(seconds: remaining))
                        .font(.system(size: 96, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.primary)
                        .monospacedDigit()

                    HatchedProgressBar(progress: pct)
                }
            }

            HStack(spacing: 12) {
                Button { primaryAction() } label: {
                    Text(primaryButtonLabel)
                        .font(AppType.bodyMedium)
                        .kerning(1.8)
                        .foregroundStyle(AppColors.primary)
                        .frame(minWidth: 120)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().stroke(AppColors.primary, lineWidth: 2))
                }
                .buttonStyle(.plain)

                if timer.phase != .idle {
                    Button { timer.reset() } label: {
                        Text("RESET")
                            .font(AppType.bodyMedium)
                            .kerning(1.8)
                            .foregroundStyle(AppColors.primary)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .overlay(Rectangle().stroke(AppColors.primary, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
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

private struct HatchedProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .strokeBorder(AppColors.primary, lineWidth: 1.5)
                let fillW = (geo.size.width - 3) * max(0, min(1, progress))
                if fillW > 0 {
                    Canvas { ctx, size in
                        let period: CGFloat = 10
                        var x: CGFloat = -size.height
                        while x < size.width + size.height {
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: size.height))
                            p.addLine(to: CGPoint(x: x + size.height, y: 0))
                            ctx.stroke(p, with: .color(AppColors.primary), lineWidth: 6)
                            x += period
                        }
                    }
                    .frame(width: fillW, height: geo.size.height - 3)
                    .clipped()
                    .offset(x: 1.5, y: 1.5)
                }
            }
        }
        .frame(height: 12)
    }
}
