import Foundation
import Observation

protocol PomodoroClock: Sendable {
    var now: Date { get }
}

struct SystemClock: PomodoroClock {
    var now: Date { .now }
}

@Observable
@MainActor
final class PomodoroTimer {
    enum Phase: String, Codable {
        case idle
        case focus
        case shortBreak
        case paused
    }

    private struct StoredState: Codable {
        var phase: Phase
        var anchor: Date?
        var phaseLength: Int
        var pausedRemaining: Int?
    }

    static let focusLengthSeconds = 25 * 60
    static let breakLengthSeconds = 5 * 60
    private static let storageKey = "pomodoro.state"

    private let clock: PomodoroClock
    private var tick: Timer?

    private(set) var phase: Phase = .idle
    private(set) var anchor: Date?
    private(set) var phaseLength: Int = 0
    private var pausedRemaining: Int?

    var remainingSeconds: Int {
        switch phase {
        case .idle:
            return Self.focusLengthSeconds
        case .paused:
            return pausedRemaining ?? 0
        case .focus, .shortBreak:
            guard let anchor else { return 0 }
            let elapsed = Int(clock.now.timeIntervalSince(anchor))
            return max(0, phaseLength - elapsed)
        }
    }

    init(clock: PomodoroClock = SystemClock()) {
        self.clock = clock
        restore()
    }

    func start() {
        switch phase {
        case .idle:
            enter(phase: .focus, length: Self.focusLengthSeconds)
            PomodoroActivity.start(phase: "focus", durationSeconds: Self.focusLengthSeconds)
        case .paused:
            if let rem = pausedRemaining {
                anchor = clock.now.addingTimeInterval(TimeInterval(-(phaseLength - rem)))
                phase = (phaseLength == Self.focusLengthSeconds) ? .focus : .shortBreak
                pausedRemaining = nil
                persist()
                startTick()
                let p = phase == .focus ? "focus" : "break"
                PomodoroActivity.update(phase: p, durationSeconds: rem)
            }
        default:
            break
        }
    }

    func pause() {
        switch phase {
        case .focus, .shortBreak:
            let rem = remainingSeconds
            pausedRemaining = rem
            phase = .paused
            stopTick()
            persist()
            PomodoroActivity.pause(remainingSeconds: rem)
        default:
            break
        }
    }

    func reset() {
        phase = .idle
        anchor = nil
        phaseLength = 0
        pausedRemaining = nil
        stopTick()
        persist()
        PomodoroActivity.end()
    }

    func advance() {
        guard phase == .focus || phase == .shortBreak else { return }
        if remainingSeconds > 0 { return }
        switch phase {
        case .focus:
            enter(phase: .shortBreak, length: Self.breakLengthSeconds)
            PomodoroActivity.update(phase: "break", durationSeconds: Self.breakLengthSeconds)
        case .shortBreak:
            reset()
        default: break
        }
    }

    private func enter(phase new: Phase, length: Int) {
        phase = new
        phaseLength = length
        anchor = clock.now
        pausedRemaining = nil
        persist()
        startTick()
    }

    private func startTick() {
        stopTick()
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.remainingSeconds == 0 { self.advance() }
            }
        }
    }

    private func stopTick() {
        tick?.invalidate()
        tick = nil
    }

    private func persist() {
        let stored = StoredState(phase: phase, anchor: anchor, phaseLength: phaseLength, pausedRemaining: pausedRemaining)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode(StoredState.self, from: data) else { return }
        phase = stored.phase
        anchor = stored.anchor
        phaseLength = stored.phaseLength
        pausedRemaining = stored.pausedRemaining
        if phase == .focus || phase == .shortBreak {
            if remainingSeconds == 0 {
                advance()
            } else {
                startTick()
            }
        }
    }
}
