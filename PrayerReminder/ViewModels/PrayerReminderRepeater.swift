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
            print("⚠️ Repeating reminder interval must be at least 60 seconds. Using 60 seconds.")
            startRepeatingReminder(for: prayer, every: 1, shouldRemind: shouldRemind)
            return
        }

        let newReminderIdentifier = repeatingReminderIdentifierPrefix + prayer.id
        let newReminderInterval = timeInterval // The desired interval in seconds

        // Check if the desired reminder is already scheduled and if its interval matches
        getScheduledRepeatingReminder { [weak self] currentScheduledRequest in
            guard let self = self else { return }

            var needsReschedule = true

            if let currentRequest = currentScheduledRequest,
               currentRequest.identifier == newReminderIdentifier,
               let timeIntervalTrigger = currentRequest.trigger as? UNTimeIntervalNotificationTrigger {
                
                // If the identifier matches AND the interval matches, no reschedule needed
                if timeIntervalTrigger.timeInterval == newReminderInterval {
                    print("ℹ️ Repeating reminder for \(prayer.name) is already scheduled with the correct interval. No action needed.")
                    needsReschedule = false
                } else {
                    // Identifier matches, but interval is different. Needs reschedule.
                    print("🔄 Repeating reminder for \(prayer.name) found with different interval (\(timeIntervalTrigger.timeInterval)s vs \(newReminderInterval)s). Rescheduling.")
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [currentRequest.identifier])
                }
            } else if let currentRequest = currentScheduledRequest {
                // A different repeating reminder is scheduled (different prayer), stop it.
                print("🛑 Stopped old repeating reminder (ID: \(currentRequest.identifier)) to schedule new one for \(prayer.name).")
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [currentRequest.identifier])
            }

            if needsReschedule {
                // Now schedule the new one
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("Reminder to Pray", comment: "Repeating reminder notification title")
                content.body = String(format: NSLocalizedString("You haven’t marked %@ as prayed yet.", comment: "Repeating reminder notification body"), prayer.name)
                content.sound = .default
                content.categoryIdentifier = PrayerNotificationScheduler.prayerCategoryIdentifier // Assign the custom category

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: newReminderInterval, repeats: true)
                let request = UNNotificationRequest(identifier: newReminderIdentifier, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Failed to schedule repeating reminder for \(prayer.name): \(error)")
                    } else {
                        print("✅ Scheduled repeating reminder for \(prayer.name) every \(minutes) minutes (ID: \(newReminderIdentifier))")
                    }
                    self.printPendingNotifications() // Print after scheduling
                }
            }
            self.printPendingNotifications() // Always print pending notifications at the end of this block
        }
    }

    // Stops a specific repeating reminder by its prayer ID
    func stopRepeatingReminder(for prayer: Prayer) {
        let identifierToCancel = repeatingReminderIdentifierPrefix + prayer.id
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifierToCancel])
        print("🛑 Stopped repeating reminder for \(prayer.name) (ID: \(identifierToCancel))")
        printPendingNotifications() // Print after stopping
    }
    
    // Stops all repeating reminders managed by this class
    func stopAllRepeatingReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let repeatingReminderIdentifiers = requests
                .filter { $0.identifier.hasPrefix(self.repeatingReminderIdentifierPrefix) }
                .map { $0.identifier }
            
            if !repeatingReminderIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: repeatingReminderIdentifiers)
                print("🛑 Stopped all \(repeatingReminderIdentifiers.count) previously scheduled repeating reminders.")
            }
            self.printPendingNotifications() // Print after clearing to confirm
        }
    }

    // Debugging function to print all pending notification requests
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
