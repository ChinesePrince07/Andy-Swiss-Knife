import XCTest
@testable import AndySwissKnife

final class MockClock: PomodoroClock, @unchecked Sendable {
    private var current: Date
    init(_ start: Date) { self.current = start }
    var now: Date { current }
    func advance(seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

@MainActor
final class PomodoroTimerTests: XCTestCase {
    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "pomodoro.state")
    }

    func testStartFromIdle() {
        let clock = MockClock(Date(timeIntervalSince1970: 1_700_000_000))
        let t = PomodoroTimer(clock: clock)
        XCTAssertEqual(t.phase, .idle)
        t.start()
        XCTAssertEqual(t.phase, .focus)
        XCTAssertEqual(t.remainingSeconds, PomodoroTimer.focusLengthSeconds)
    }

    func testRemainingCountsDown() {
        let clock = MockClock(Date(timeIntervalSince1970: 1_700_000_000))
        let t = PomodoroTimer(clock: clock)
        t.start()
        clock.advance(seconds: 60)
        XCTAssertEqual(t.remainingSeconds, PomodoroTimer.focusLengthSeconds - 60)
    }

    func testAdvanceFromFocusToBreakAtZero() {
        let clock = MockClock(Date(timeIntervalSince1970: 1_700_000_000))
        let t = PomodoroTimer(clock: clock)
        t.start()
        clock.advance(seconds: TimeInterval(PomodoroTimer.focusLengthSeconds))
        t.advance()
        XCTAssertEqual(t.phase, .shortBreak)
        XCTAssertEqual(t.remainingSeconds, PomodoroTimer.breakLengthSeconds)
    }

    func testPauseAndResumePreservesRemaining() {
        let clock = MockClock(Date(timeIntervalSince1970: 1_700_000_000))
        let t = PomodoroTimer(clock: clock)
        t.start()
        clock.advance(seconds: 300)
        t.pause()
        let paused = t.remainingSeconds
        XCTAssertEqual(paused, PomodoroTimer.focusLengthSeconds - 300)

        clock.advance(seconds: 600)
        XCTAssertEqual(t.phase, .paused)
        XCTAssertEqual(t.remainingSeconds, paused)

        t.start()
        XCTAssertEqual(t.phase, .focus)
        XCTAssertEqual(t.remainingSeconds, paused)
    }

    func testResetReturnsToIdle() {
        let clock = MockClock(Date(timeIntervalSince1970: 1_700_000_000))
        let t = PomodoroTimer(clock: clock)
        t.start()
        clock.advance(seconds: 120)
        t.reset()
        XCTAssertEqual(t.phase, .idle)
    }
}
