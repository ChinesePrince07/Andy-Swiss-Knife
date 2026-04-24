import Foundation
import Observation

enum DashboardCard: String, CaseIterable, Identifiable, Codable {
    case nextClass = "nextClass"
    case canvas = "canvas"
    case meal = "meal"
    case events = "events"
    case athletics = "athletics"
    case pomodoro = "pomodoro"
    case apExams = "apExams"
    case countdown = "countdown"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nextClass: return "Next class"
        case .canvas:    return "Canvas"
        case .meal:      return "Meal"
        case .events:    return "Events"
        case .athletics: return "Athletics"
        case .pomodoro:  return "Pomodoro"
        case .apExams:   return "AP Exams"
        case .countdown: return "Countdown"
        }
    }

    var iconName: String {
        switch self {
        case .nextClass: return "graduationcap"
        case .canvas:    return "book"
        case .meal:      return "fork.knife"
        case .events:    return "calendar.badge.clock"
        case .athletics: return "figure.run"
        case .pomodoro:  return "timer"
        case .apExams:   return "pencil.and.list.clipboard"
        case .countdown: return "hourglass"
        }
    }
}

@Observable
@MainActor
final class DashboardLayout {
    static let shared = DashboardLayout()
    private static let activeKey = "dashboard.active.v2"
    private static let defaultActive: [DashboardCard] = [.nextClass, .canvas, .meal, .athletics]

    var active: [DashboardCard] {
        didSet { persist() }
    }

    var inactive: [DashboardCard] {
        DashboardCard.allCases.filter { !active.contains($0) }
    }

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.activeKey) ?? []
        let decoded = stored.compactMap(DashboardCard.init(rawValue:))
        if !decoded.isEmpty {
            self.active = decoded
        } else {
            self.active = Self.defaultActive
        }
    }

    private func persist() {
        UserDefaults.standard.set(active.map(\.rawValue), forKey: Self.activeKey)
    }

    func move(from source: IndexSet, to destination: Int) {
        active.move(fromOffsets: source, toOffset: destination)
    }

    func activate(_ card: DashboardCard) {
        guard !active.contains(card) else { return }
        active.append(card)
    }

    func deactivate(_ card: DashboardCard) {
        active.removeAll { $0 == card }
    }

    func resetDefault() {
        active = Self.defaultActive
    }
}
