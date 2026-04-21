import Foundation
import Observation

enum DashboardCard: String, CaseIterable, Identifiable, Codable {
    case nextClass = "nextClass"
    case reminders = "reminders"
    case canvas = "canvas"
    case meal = "meal"
    case pomodoro = "pomodoro"
    case events = "events"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nextClass: return "Next class"
        case .reminders: return "Reminders"
        case .canvas:    return "Canvas"
        case .meal:      return "Meal"
        case .pomodoro:  return "Pomodoro"
        case .events:    return "Events"
        }
    }

    var iconName: String {
        switch self {
        case .nextClass: return "graduationcap"
        case .reminders: return "calendar"
        case .canvas:    return "book"
        case .meal:      return "fork.knife"
        case .pomodoro:  return "timer"
        case .events:    return "calendar.badge.clock"
        }
    }
}

@Observable
@MainActor
final class DashboardLayout {
    static let shared = DashboardLayout()
    private static let key = "dashboard.layout.v1"

    var order: [DashboardCard] {
        didSet { persist() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([DashboardCard].self, from: data) {
            // Append any newly added cards that aren't in persisted layout.
            let missing = DashboardCard.allCases.filter { !decoded.contains($0) }
            self.order = decoded + missing
        } else {
            self.order = DashboardCard.allCases
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }

    func resetDefault() {
        order = DashboardCard.allCases
    }
}
