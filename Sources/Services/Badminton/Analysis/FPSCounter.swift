import Foundation

final class FPSCounter {
    let window: TimeInterval
    private var times: [TimeInterval] = []

    init(window: TimeInterval = 1.0) { self.window = window }

    func tick(at time: TimeInterval) {
        times.append(time)
        let cutoff = time - window
        times.removeAll { $0 < cutoff }
    }

    var fps: Double {
        guard times.count >= 2, let first = times.first, let last = times.last, last > first else { return 0 }
        return Double(times.count - 1) / (last - first)
    }
}
