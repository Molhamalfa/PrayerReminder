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
    
    // Determines which prayer is currently in its active window.
    func isPrayerCurrentlyActive(_ prayer: Prayer, allPrayers: [Prayer]) -> Bool {
        guard prayer.name != "Sunrise" else { return false }
        
        guard let prayerDate = date(for: prayer.time, basedOn: Date()) else { return false }
        
        // Find the next prayer in the list to determine the end of the current prayer's window.
        guard let nextPrayer = allPrayers.first(where: { $0.name != "Sunrise" && date(for: $0.time, basedOn: Date())! > prayerDate }) else {
            // This is the last prayer of the day (Isha). The window ends at midnight.
            return Date() >= prayerDate && Date() < date(for: "23:59", basedOn: Date())!
        }
        
        guard let nextPrayerDate = date(for: nextPrayer.time, basedOn: Date()) else { return false }

        let now = Date()
        return now >= prayerDate && now < nextPrayerDate
    }
    
    // Checks if the prayer's active window has ended.
    func hasPrayerWindowEnded(for prayer: Prayer, allPrayers: [Prayer]) -> Bool {
        guard prayer.name != "Sunrise" else { return false }
        
        guard let prayerDate = date(for: prayer.time, basedOn: Date()) else { return false }
        
        // Find the next prayer to determine the end of the current prayer's window.
        guard let nextPrayer = allPrayers.first(where: { $0.name != "Sunrise" && date(for: $0.time, basedOn: Date())! > prayerDate }) else {
            // For the last prayer (Isha), the window ends at midnight.
            return Date() >= prayerDate && Date() > date(for: "23:59", basedOn: Date())!
        }
        
        guard let nextPrayerDate = date(for: nextPrayer.time, basedOn: Date()) else { return false }
        
        let now = Date()
        return now > nextPrayerDate
    }

    // Finds the next prayer that has not yet occurred.
    // This function will wrap around to the next day's Fajr if all prayers today have passed.
    func findNextPrayer(from prayers: [Prayer], now: Date = Date()) -> (prayer: Prayer, time: Date)? {
        let sortedPrayers = prayers.sorted { p1, p2 in
            guard let date1 = date(for: p1.time, basedOn: now),
                  let date2 = date(for: p2.time, basedOn: now) else { return false }
            return date1 < date2
        }

        for prayer in sortedPrayers {
            guard let prayerDate = date(for: prayer.time, basedOn: now) else { continue }
            
            // Only consider prayers whose time is after the current time.
            if now < prayerDate {
                return (prayer, prayerDate)
            }
        }

        // If no upcoming prayer is found today, the next prayer is Fajr tomorrow.
        if let fajr = prayers.first(where: { $0.name == "Fajr" }),
           let fajrToday = date(for: fajr.time, basedOn: now) {
            if let fajrTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: fajrToday) {
                return (fajr, fajrTomorrow)
            }
        }
        return nil
    }
    
    // Finds the prayer that is currently active.
    func findActivePrayer(from prayers: [Prayer], now: Date = Date()) -> Prayer? {
        let sortedPrayers = prayers.sorted { p1, p2 in
            guard let date1 = date(for: p1.time, basedOn: now),
                  let date2 = date(for: p2.time, basedOn: now) else { return false }
            return date1 < date2
        }
        
        // The active prayer is the one whose time has passed, but the next prayer's time has not.
        for (index, prayer) in sortedPrayers.enumerated() {
            guard prayer.name != "Sunrise" else { continue }
            guard let prayerDate = date(for: prayer.time, basedOn: now) else { continue }
            
            // If the current time is after this prayer's time...
            if now >= prayerDate {
                // ...and this is the last prayer (Isha), it's active until midnight.
                if index == sortedPrayers.count - 1 {
                    return prayer
                }
                
                // ...or if the current time is before the next prayer's time, this is the active prayer.
                if let nextPrayer = sortedPrayers[safe: index + 1],
                   let nextPrayerDate = date(for: nextPrayer.time, basedOn: now) {
                    if now < nextPrayerDate {
                        return prayer
                    }
                }
            }
        }
        return nil
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
        return indices.contains(index) ? self[index] : nil
    }
}
