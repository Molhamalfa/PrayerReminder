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
            
            let notificationIdentifier = "prayer-reminder-\(prayer.name)"
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Prayer Time", comment: "Notification title for prayer time")
            content.body = String(format: NSLocalizedString("It's time for %@.", comment: "Notification body for prayer time"), NSLocalizedString(prayer.name, comment: ""))
            content.sound = UNNotificationSound.default
            content.userInfo = ["prayerName": prayer.name]
            content.categoryIdentifier = PrayerNotificationScheduler.prayerCategoryIdentifier

            if let prayerDate = getDate(from: prayer.time) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: prayerDate)
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Error scheduling notification for \(prayer.name): \(error.localizedDescription)")
                    } else {
                        print("✅ Scheduled notification for \(prayer.name) at \(prayer.time) with ID: \(notificationIdentifier)")
                    }
                }
            } else {
                print("❌ Could not create date for prayer: \(prayer.name) at \(prayer.time)")
            }
        }
    }
    
    func cancelSpecificNotification(forPrayerNamed prayerName: String) {
        let identifierToCancel = "prayer-reminder-\(prayerName)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifierToCancel])
        print("🔕 Cancelled notification for \(prayerName) with ID: \(identifierToCancel)")
    }

    func listPendingNotifications() {
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
