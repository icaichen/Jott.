import EventKit
import Foundation

@MainActor
final class RemindersBridge {
    static let shared = RemindersBridge()

    private let store = EKEventStore()

    private var canUseReminders: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    private init() {}

    func requestAccessIfNeeded() async -> Bool {
        guard canUseReminders else { return false }
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            return false
        case .notDetermined:
            do {
                if #available(macOS 14.0, *) {
                    return try await store.requestFullAccessToReminders()
                } else {
                    return try await store.requestAccess(to: .reminder)
                }
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func createReminder(title: String, notes: String?, dueAt: Date) async -> String? {
        guard await requestAccessIfNeeded() else { return nil }
        guard let calendar = store.defaultCalendarForNewReminders() else { return nil }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = calendar

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueAt)
        reminder.dueDateComponents = comps

        do {
            try store.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            return nil
        }
    }

    func deleteReminder(id: String) async {
        guard await requestAccessIfNeeded() else { return }
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        try? store.remove(reminder, commit: true)
    }

    func completeReminder(id: String) async {
        guard await requestAccessIfNeeded() else { return }
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
    }
}

