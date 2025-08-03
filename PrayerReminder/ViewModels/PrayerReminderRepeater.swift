//
//  PrayerReminderRepeater.swift
//  PrayerReminder
//
//  Created by Mac on 25.07.2025.
//


import Foundation
import UserNotifications

class PrayerReminderRepeater {
    static let shared = PrayerReminderRepeater()
    
    private init() {}

    // Identifier prefix for repeating reminders, allowing easy cancellation
    private let repeatingReminderIdentifierPrefix = "repeating-prayer-reminder-"

    // NEW: Get the currently scheduled repeating reminder request (if any)
    func getScheduledRepeatingReminder(completion: @escaping (UNNotificationRequest?) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let repeatingReminder = requests.first { $0.identifier.hasPrefix(self.repeatingReminderIdentifierPrefix) }
            completion(repeatingReminder)
        }
    }

    func startRepeatingReminder(for prayer: Prayer, every minutes: Int, shouldRemind: Bool) {
        print("  PrayerReminderRepeater: Received 'shouldRemind' as: \(shouldRemind)")
        print("  PrayerReminderRepeater: Received 'minutes' as: \(minutes)") // Debugging print

        guard shouldRemind else {
            print("🔕 Repeating reminders disabled as per ViewModel's instruction.")
            stopAllRepeatingReminders()
            return
        }

        let timeInterval = TimeInterval(minutes * 60)
        
        guard timeInterval >= 60 else {
            print("⚠️ Repeating reminder interval must be at least 60 seconds. Using 60 seconds instead.")
            return
        }

        let identifier = "\(repeatingReminderIdentifierPrefix)\(prayer.name)"
        
        // Remove any existing repeating reminders before scheduling a new one.
        stopAllRepeatingReminders()

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Prayer Reminder", comment: "Repeating notification title")
        content.body = String(format: NSLocalizedString("Have you prayed %@ yet?", comment: "Repeating notification body"), NSLocalizedString(prayer.name, comment: ""))
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = PrayerNotificationScheduler.prayerCategoryIdentifier
        content.userInfo = ["prayerName": prayer.name]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling repeating reminder for \(prayer.name): \(error.localizedDescription)")
            } else {
                print("⏰ Repeating reminder for \(prayer.name) scheduled to fire every \(minutes) minutes.")
            }
        }
        
        // Print all scheduled notifications for debugging
        printPendingNotifications()
    }
    
    func stopAllRepeatingReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let repeatingReminders = requests.filter { $0.identifier.hasPrefix(self.repeatingReminderIdentifierPrefix) }
            let identifiersToRemove = repeatingReminders.map { $0.identifier }
            if !identifiersToRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("🔕 Stopped \(identifiersToRemove.count) repeating reminders.")
            }
        }
    }

    // NEW: Function to remove a specific repeating reminder
    func removeRepeatingReminder(for prayer: Prayer) {
        let identifier = "\(repeatingReminderIdentifierPrefix)\(prayer.name)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🔕 Removed pending repeating reminder for \(prayer.name) with identifier: \(identifier)")
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
}
