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
    private let prayerNotificationIdentifierPrefix = "prayer-reminder-"

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

    func scheduleNotifications(for prayers: [Prayer]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        for prayer in prayers {
            guard prayer.status == .upcoming else { continue }
            
            let notificationIdentifier = "\(prayerNotificationIdentifierPrefix)\(prayer.name)"
            
            // Only schedule if the prayer time is in the future.
            let now = Date()
            let prayerDate = getDate(from: prayer.time)
            
            guard let prayerDate = prayerDate, now < prayerDate else {
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Prayer Reminder", comment: "Notification title for prayer reminder")
            content.body = String(format: NSLocalizedString("It's time for %@.", comment: "Notification body for prayer reminder"), NSLocalizedString(prayer.name, comment: ""))
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = PrayerNotificationScheduler.prayerCategoryIdentifier
            content.userInfo = ["prayerName": prayer.name]

            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: prayerDate)

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling prayer notification for \(prayer.name): \(error.localizedDescription)")
                } else {
                    print("🔔 Prayer notification scheduled for \(prayer.name) at \(prayer.time).")
                }
            }
        }
        
        // Print all scheduled notifications for debugging
        printPendingNotifications()
    }
    
    // NEW: Function to remove a single pending notification
    func removeNotification(for prayer: Prayer) {
        let identifier = "\(prayerNotificationIdentifierPrefix)\(prayer.name)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🔕 Removed pending notification for \(prayer.name) with identifier: \(identifier)")
    }
    
    // Debugging function to print all pending notifications
    func printPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("\n--- Pending Notification Requests (\(requests.count)) ---")
            if requests.isEmpty {
                print("No pending notifications.")
            } else {
                for request in requests {
                    print("  ID: \(request.identifier)")
                    print("  Title: \(request.content.title)")
                    print("  Body: \(request.content.body)")
                    if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                        let hour = calendarTrigger.dateComponents.hour ?? 0
                        let minute = calendarTrigger.dateComponents.minute ?? 0
                        print(String(format: "  Trigger Time: %02d:%02d (repeats: %@)", hour, minute, calendarTrigger.repeats ? "true" : "false" as NSString))
                    } else if let timeIntervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                        print(String(format: "  Trigger Interval: %.0f seconds (repeats: %@)", timeIntervalTrigger.timeInterval, timeIntervalTrigger.repeats ? "true" : "false" as NSString))
                    } else {
                        print("  Trigger Type: Unknown")
                    }
                    print("---------------------------------------")
                }
            }
            print("-----------------------------------\n")
        }
    }

    private func getDate(from timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: timeString)
    }
}
