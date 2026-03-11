//
//  NotificationManager.swift
//  sprout-pomodoro
//

import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendFocusFinishedNotification() {
        send(title: "Focus Complete!", body: "Time to take a break.")
    }

    func sendBreakFinishedNotification() {
        send(title: "Break Over!", body: "Time to get back to work.")
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}
