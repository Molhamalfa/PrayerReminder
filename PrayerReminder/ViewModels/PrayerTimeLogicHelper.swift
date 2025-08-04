//
//  PrayerTimeLogicHelper.swift
//  PrayerReminder
//
//  Created by Mac on 25.07.2025.
//

import Foundation
import UserNotifications

class PrayerTimeLogicHelper {

    // Helper function to combine a time string with a base date to create a new Date object.
    func date(for timeString: String, basedOn baseDate: Date) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone.current

        guard let time = dateFormatter.date(from: timeString) else { return nil }

        let calendar = Calendar.current
        let baseDateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combinedComponents = DateComponents()
        combinedComponents.year = baseDateComponents.year
        combinedComponents.month = baseDateComponents.month
        combinedComponents.day = baseDateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = 0

        return calendar.date(from: combinedComponents)
    }

    // Determines if a given prayer's time has passed the current time.
    func hasPrayerTimePassed(for prayer: Prayer) -> Bool {
        guard let prayerDate = date(for: prayer.time, basedOn: Date()) else { return false }
        return Date() > prayerDate
    }
    
    // Determines if a prayer is currently active (within its prayer time window).
    func isPrayerCurrentlyActive(for prayer: Prayer, allPrayers: [Prayer]) -> Bool {
        guard let prayerDate = date(for: prayer.time, basedOn: Date()) else { return false }
        let now = Date()

        // The prayer is active if the current time is between its start time and the start time of the next prayer.
        if let nextPrayer = getPrayerAfter(prayer, from: allPrayers),
           let nextPrayerDate = date(for: nextPrayer.time, basedOn: now) {
            return now >= prayerDate && now < nextPrayerDate
        } else {
            // If it's the last prayer of the day (Isha), the window ends at midnight.
            return now >= prayerDate
        }
    }

    // Determines if a prayer's window for completion has ended.
    // It's considered ended if the next prayer's time has been reached.
    func hasPrayerWindowEnded(for prayer: Prayer, allPrayers: [Prayer]) -> Bool {
        guard let nextPrayer = getPrayerAfter(prayer, from: allPrayers),
              let nextPrayerDate = date(for: nextPrayer.time, basedOn: Date()) else {
            // If there's no next prayer (e.g., it's Isha), the window effectively ends at midnight.
            return false
        }
        return Date() > nextPrayerDate
    }
    
    // Finds the next prayer after the given prayer in the list.
    func getPrayerAfter(_ prayer: Prayer, from prayers: [Prayer]) -> Prayer? {
        if let currentIndex = prayers.firstIndex(where: { $0.id == prayer.id }) {
            let nextIndex = currentIndex + 1
            if prayers.indices.contains(nextIndex) {
                return prayers[nextIndex]
            }
        }
        return nil
    }

    // Retrieves the next prayer that is marked as `.upcoming`, along with its `Date` object.
    func getNextUpcomingPrayer(from prayers: [Prayer], after currentTime: Date = Date()) -> (prayer: Prayer, prayerDate: Date)? {
        for prayer in prayers {
            if prayer.status == .upcoming {
                if let prayerDate = date(for: prayer.time, basedOn: currentTime) {
                    if currentTime < prayerDate {
                        return (prayer, prayerDate)
                    }
                }
            }
        }
        
        // If all prayers have passed for the day, return the first prayer of the next day
        // This is a simplified approach, a more robust solution would involve fetching data for the next day
        guard let firstPrayer = prayers.first else { return nil }
        
        if let prayerDate = date(for: firstPrayer.time, basedOn: currentTime) {
            return (firstPrayer, prayerDate)
        }
        
        // If all prayers have passed, default to the first prayer of the current list.
        return prayers.first.map { ($0, date(for: $0.time, basedOn: currentTime)!) }
    }
    
    // Formats a time interval into a user-friendly string (e.g., "02h 30m").
    func format(timeInterval: TimeInterval) -> String {
        let absoluteInterval = abs(timeInterval)
        let hours = Int(absoluteInterval) / 3600
        let minutes = Int(absoluteInterval) % 3600 / 60

        if hours > 0 {
            return String(format: NSLocalizedString("%02dh %02dm", comment: "Hours and minutes format"), hours, minutes)
        } else {
            return String(format: NSLocalizedString("%02dm", comment: "Minutes format"), minutes)
        }
    }

    // Determines if it's currently daytime based on Fajr and Maghrib prayer times.
    func isDaytime(prayers: [Prayer], currentTime: Date = Date()) -> Bool {
        guard let fajr = prayers.first(where: { $0.name == "Fajr" }),
              let maghrib = prayers.first(where: { $0.name == "Maghrib" }) else {
            // Default to true if prayers are not available.
            return true
        }

        guard let fajrDate = date(for: fajr.time, basedOn: currentTime),
              let maghribDate = date(for: maghrib.time, basedOn: currentTime) else {
            return true
        }
        
        return currentTime > fajrDate && currentTime < maghribDate
    }
}

// Simple extension for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else { return nil }
        return self[index]
    }
}
