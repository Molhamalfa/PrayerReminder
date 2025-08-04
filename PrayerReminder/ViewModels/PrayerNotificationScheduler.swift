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
            
            let identifier = "\(prayerNotificationIdentifierPrefix)\(prayer.name)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification for \(prayer.name): \(error.localizedDescription)")
                } else {
                    print("✅ Successfully scheduled notification for \(prayer.name) at \(prayer.time) with ID: \(identifier)")
                }
            }
        }
        
        // For debugging, print all pending notifications after scheduling
        printPendingNotifications()
    }

    func stopAllPrayerNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All pending prayer notifications removed.")
    }
    
    // NEW: Function to remove notifications for a specific prayer
    func removePendingNotifications(for prayer: Prayer) {
        let identifier = "\(prayerNotificationIdentifierPrefix)\(prayer.name)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Removed notification with identifier: \(identifier)")
    }

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
