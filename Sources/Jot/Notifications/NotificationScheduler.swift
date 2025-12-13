import Foundation
import UserNotifications

actor NotificationScheduler {
    static let shared = NotificationScheduler()

    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    private func center() -> UNUserNotificationCenter? {
        guard canUseNotifications else { return nil }
        return UNUserNotificationCenter.current()
    }

    func requestAuthorizationIfNeeded() async {
        guard let center = center() else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleTodo(id: UUID, noteTitle: String, text: String, dueAt: Date) async {
        guard let center = center() else { return }
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = noteTitle
        content.body = text
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: dueAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier(for: id),
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    func cancelTodo(id: UUID) async {
        guard let center = center() else { return }
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: id)])
    }

    private func identifier(for id: UUID) -> String {
        "todo-\(id.uuidString)"
    }
}
