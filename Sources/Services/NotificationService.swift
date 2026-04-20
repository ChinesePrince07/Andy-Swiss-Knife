import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    func schedule(for todo: Todo) async {
        guard let due = todo.dueDate, !todo.isDone else { return }
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let center = UNUserNotificationCenter.current()

        if let existingID = todo.notificationID {
            center.removePendingNotificationRequests(withIdentifiers: [existingID])
        }

        let content = UNMutableNotificationContent()
        content.title = todo.title
        content.body = "Due now"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due),
            repeats: false
        )

        let identifier = todo.notificationID ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            todo.notificationID = identifier
        } catch {
            todo.notificationID = nil
        }
    }

    func cancel(for todo: Todo) {
        guard let id = todo.notificationID else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        todo.notificationID = nil
    }
}
