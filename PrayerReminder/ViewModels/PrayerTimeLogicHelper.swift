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

        if let nextPrayer = getPrayerAfter(prayer, from: allPrayers),
           let nextPrayerDate = date(for: nextPrayer.time, basedOn: now) {
            return now >= prayerDate && now < nextPrayerDate
        } else {
            // If it's the last prayer of the day (Isha), the window is active until midnight.
            return now >= prayerDate
        }
    }

    // Determines if a prayer's window for completion has ended.
    func hasPrayerWindowEnded(for prayer: Prayer, allPrayers: [Prayer]) -> Bool {
        guard let nextPrayer = getPrayerAfter(prayer, from: allPrayers),
              let nextPrayerDate = date(for: nextPrayer.time, basedOn: Date()) else {
            // No next prayer means it's Isha. Its window hasn't ended until the day is over.
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
    
    /// Creates pairs of (Current Prayer, Next Prayer) to define prayer windows.
    /// This is used for scheduling repeating reminders.
    func getPrayerWindows(from prayers: [Prayer]) -> [(current: Prayer, next: Prayer)] {
        // Filter out "Sunrise" as it does not have a prayer window for reminders.
        let relevantPrayers = prayers.filter { $0.name != "Sunrise" }
        guard !relevantPrayers.isEmpty else { return [] }
        
        var windows: [(current: Prayer, next: Prayer)] = []
        // Iterate up to the second-to-last prayer to create pairs.
        for i in 0..<(relevantPrayers.count - 1) {
            windows.append((current: relevantPrayers[i], next: relevantPrayers[i+1]))
        }
        
        // **FIX**: Manually create a window for the last prayer (Isha) until the end of the day.
        if let lastPrayer = relevantPrayers.last {
            // Create a "dummy" prayer to represent the end of the day for the window calculation.
            let endOfDayPrayer = Prayer(name: "EndOfDay", time: "23:59", status: .upcoming)
            windows.append((current: lastPrayer, next: endOfDayPrayer))
        }
        
        return windows
    }

    /// Retrieves the next prayer that is marked as `.upcoming`, along with its `Date` object.
    func getNextUpcomingPrayer(from prayers: [Prayer], after currentTime: Date = Date()) -> (prayer: Prayer, prayerDate: Date)? {
        let upcomingToday = prayers
            .filter { $0.status == .upcoming }
            .compactMap { prayer -> (Prayer, Date)? in
                guard let prayerDate = date(for: prayer.time, basedOn: currentTime) else { return nil }
                return (prayer, prayerDate)
            }
            .first { $0.1 > currentTime }

        if let nextPrayerToday = upcomingToday {
            return nextPrayerToday
        }
        
        guard let firstPrayerOfList = prayers.first,
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: currentTime),
              let firstPrayerTomorrowDate = date(for: firstPrayerOfList.time, basedOn: tomorrow) else {
            return nil
        }
        
        var nextDayPrayer = firstPrayerOfList
        nextDayPrayer.status = .upcoming
        
        return (nextDayPrayer, firstPrayerTomorrowDate)
    }
    
    // Formats a time interval into a user-friendly string (e.g., "02h 30m").
    func format(timeInterval: TimeInterval) -> String {
        guard timeInterval > 0 else { return "00m" }
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
        guard !prayers.isEmpty,
              let fajr = prayers.first(where: { $0.name == "Fajr" }),
              let maghrib = prayers.first(where: { $0.name == "Maghrib" }) else {
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
