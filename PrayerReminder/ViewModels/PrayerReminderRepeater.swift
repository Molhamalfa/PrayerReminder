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

        // Stop any existing repeating reminders before starting a new one.
        stopAllRepeatingReminders()

        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Prayer Reminder", comment: "Repeating reminder title")
        content.body = String(format: NSLocalizedString("Have you prayed %@ yet? Tap 'Prayed' to stop these reminders.", comment: "Repeating reminder body"), NSLocalizedString(prayer.name, comment: ""))
        content.sound = .default
        content.categoryIdentifier = PrayerNotificationScheduler.prayerCategoryIdentifier // Use the same category
        content.userInfo = ["prayerName": prayer.name] // Pass prayer name for handling actions

        // Create a time-interval trigger that repeats.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: true)

        // Create the notification request
        let identifier = repeatingReminderIdentifierPrefix + prayer.id
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ PrayerReminderRepeater: Error scheduling repeating reminder for \(prayer.name): \(error.localizedDescription)")
            } else {
                print("✅ PrayerReminderRepeater: Scheduled repeating reminder for \(prayer.name) every \(minutes) minutes.")
            }
        }
    }
    
    func stopAllRepeatingReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let repeatingReminderIdentifiers = requests
                .filter { $0.identifier.hasPrefix(self.repeatingReminderIdentifierPrefix) }
                .map { $0.identifier }
            
            guard !repeatingReminderIdentifiers.isEmpty else {
                print("ℹ️ PrayerReminderRepeater: No repeating reminders to stop.")
                return
            }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: repeatingReminderIdentifiers)
            print("🔕 PrayerReminderRepeater: Stopped \(repeatingReminderIdentifiers.count) repeating reminders.")
            
        }
    }
}
