//
//  PrayerNotificationScheduler.swift
//  PrayerReminder
//
//  Created by Mac on 25.07.2025.
//

import Foundation
import UserNotifications

class PrayerNotificationScheduler {
    static let shared = PrayerNotificationScheduler()
    
    static let prayedActionIdentifier = "PRAYED_ACTION"
    static let prayerCategoryIdentifier = "PRAYER_REMINDER_CATEGORY"
    // A unique prefix for all main prayer time notifications.
    private let mainNotificationIdentifierPrefix = "main-prayer-reminder-"

    private init() {}

    func registerNotificationCategory() {
        let prayedAction = UNNotificationAction(
            identifier: PrayerNotificationScheduler.prayedActionIdentifier,
            title: NSLocalizedString("Prayed", comment: "Notification action button title for marking prayer as prayed"),
            options: [.foreground]
        )

        let prayerCategory = UNNotificationCategory(
            identifier: PrayerNotificationScheduler.prayerCategoryIdentifier,
            actions: [prayedAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([prayerCategory])
        print("✅ Notification category '\(PrayerNotificationScheduler.prayerCategoryIdentifier)' registered.")
    }

    /// Schedules the main, one-time notification for each upcoming prayer.
    func scheduleNotifications(for prayers: [Prayer]) {
        for prayer in prayers {
            // Only schedule for prayers that haven't been completed or missed.
            guard prayer.status == .upcoming else { continue }
            
            guard let date = getDate(from: prayer.time) else {
                print("❌ Failed to create date from prayer time: \(prayer.time)")
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("It's time to pray", comment: "Notification title for prayer reminder")
            content.body = String(format: NSLocalizedString("The time for %@ is now.", comment: "Notification body for prayer reminder"), NSLocalizedString(prayer.name, comment: ""))
            content.sound = .default
            content.userInfo = ["prayerName": prayer.name]
            content.categoryIdentifier = PrayerNotificationScheduler.prayerCategoryIdentifier
            
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let identifier = "\(mainNotificationIdentifierPrefix)\(prayer.name)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling main notification for \(prayer.name): \(error.localizedDescription)")
                } else {
                    print("✅ Successfully scheduled main notification for \(prayer.name) at \(prayer.time)")
                }
            }
        }
    }

    /// Removes the main pending notification for a specific prayer.
    func removePendingNotifications(for prayer: Prayer) {
        let identifier = "\(mainNotificationIdentifierPrefix)\(prayer.name)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Removed main notification for \(prayer.name).")
    }
    
    /// Cancels ALL scheduled notifications (both main and repeating).
    /// This is used to clear everything before a full refresh.
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All pending notifications have been cancelled.")
    }

    private func getDate(from timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: timeString)
    }
}
