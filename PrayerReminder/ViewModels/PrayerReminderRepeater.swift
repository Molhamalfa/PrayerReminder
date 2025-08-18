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

    // A unique prefix for all repeating reminder notifications.
    private let repeatingReminderIdentifierPrefix = "repeating-prayer-reminder-"

    /// Schedules all potential follow-up reminders for the entire day in advance.
    /// This ensures reminders are delivered by the OS even if the app is terminated.
    func scheduleAllFollowUpReminders(for prayers: [Prayer], every minutes: Int, using timeHelper: PrayerTimeLogicHelper) {
        print("🔁 Scheduling all potential follow-up reminders for the day...")
        
        let prayerWindows = timeHelper.getPrayerWindows(from: prayers)
        
        for (currentPrayer, nextPrayer) in prayerWindows {
            // We only need to schedule reminders for prayers that are still upcoming.
            guard currentPrayer.status == .upcoming else { continue }
            
            guard let prayerStartDate = timeHelper.date(for: currentPrayer.time, basedOn: Date()),
                  let prayerEndDate = timeHelper.date(for: nextPrayer.time, basedOn: Date()) else {
                continue
            }
            
            // Start the first reminder 'minutes' after the prayer time begins.
            var reminderTime = prayerStartDate.addingTimeInterval(TimeInterval(minutes * 60))
            var reminderCount = 1
            
            // Loop and create a notification for each interval until the window ends.
            while reminderTime < prayerEndDate {
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("Prayer Reminder", comment: "Repeating reminder title")
                content.body = String(format: NSLocalizedString("Have you prayed %@ yet? Tap 'Prayed' to stop these reminders.", comment: "Repeating reminder body"), NSLocalizedString(currentPrayer.name, comment: ""))
                content.sound = .default
                content.categoryIdentifier = PrayerNotificationScheduler.prayerCategoryIdentifier
                content.userInfo = ["prayerName": currentPrayer.name]

                // **FIX**: Use a more specific date component for the trigger to ensure reliability.
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                // Create a unique identifier for each individual reminder.
                let identifier = "\(repeatingReminderIdentifierPrefix)\(currentPrayer.name)-\(reminderCount)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ PrayerReminderRepeater: Error scheduling follow-up reminder for \(currentPrayer.name) at \(reminderTime): \(error.localizedDescription)")
                    }
                }
                
                // Move to the next reminder time.
                reminderTime = reminderTime.addingTimeInterval(TimeInterval(minutes * 60))
                reminderCount += 1
            }
            print("  ✅ Pre-scheduled \(reminderCount - 1) follow-up reminders for \(currentPrayer.name).")
        }
    }
    
    /// Cancels all scheduled repeating reminders for a specific prayer.
    /// This is called when the user marks a prayer as completed.
    func cancelRepeatingReminders(for prayer: Prayer) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToCancel = requests
                .filter { $0.identifier.hasPrefix("\(self.repeatingReminderIdentifierPrefix)\(prayer.name)-") }
                .map { $0.identifier }
            
            if !identifiersToCancel.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
                print("🔕 PrayerReminderRepeater: Cancelled \(identifiersToCancel.count) repeating reminders for \(prayer.name).")
            }
        }
    }
}
