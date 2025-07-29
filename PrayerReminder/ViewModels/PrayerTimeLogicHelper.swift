//
//  PrayerTimeLogicHelper.swift
//  PrayerReminder
//
//  Created by Mac on 25.07.2025.
//

import Foundation
import UserNotifications

class PrayerTimeLogicHelper {

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

    func hasPrayerTimePassed(for prayer: Prayer) -> Bool {
        guard let prayerDate = date(for: prayer.time, basedOn: Date()) else { return false }
        return Date() > prayerDate
    }
    
    func isPrayerCurrentlyActive(_ prayer: Prayer, allPrayers: [Prayer]) -> Bool {
        guard prayer.name != "Sunrise" else { return false }
        
        guard let prayerDate = date(for: prayer.time, basedOn: Date()) else { return false }
        let now = Date()

        guard now >= prayerDate else { return false }

        if let currentIndex = allPrayers.firstIndex(where: { $0.id == prayer.id }) {
            let subsequentPrayers = allPrayers.dropFirst(currentIndex + 1)
            
            // For active check, we still want to skip Sunrise if it's the *next prayer to be active*
            // because Sunrise itself is not an active prayer window.
            if let nextActualPrayer = subsequentPrayers.first(where: { $0.name != "Sunrise" }) {
                guard let nextPrayerDate = date(for: nextActualPrayer.time, basedOn: Date()) else { return false }
                
                return now < nextPrayerDate
            } else {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                if let fajrTomorrow = allPrayers.first(where: { $0.name == "Fajr" }),
                   let fajrTomorrowDate = date(for: fajrTomorrow.time, basedOn: tomorrow) {
                    return now < fajrTomorrowDate
                }
                return true
            }
        }
        return false
    }

    func hasPrayerWindowEnded(for prayer: Prayer, allPrayers: [Prayer]) -> Bool {
        guard prayer.name != "Sunrise" else { return false }
        
        guard let prayerDate = date(for: prayer.time, basedOn: Date()) else { return false }
        let now = Date()

        guard now >= prayerDate else { return false }

        if let currentIndex = allPrayers.firstIndex(where: { $0.id == prayer.id }) {
            let subsequentPrayers = allPrayers.dropFirst(currentIndex + 1)
            
            // FIX: Do NOT skip Sunrise when determining the end of the *previous* prayer's window.
            // Fajr's window ends at Sunrise.
            if let nextTiming = subsequentPrayers.first { // Changed from .first(where: { $0.name != "Sunrise" })
                guard let nextTimingDate = date(for: nextTiming.time, basedOn: Date()) else { return false }
                
                return now >= nextTimingDate
            } else {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                if let fajrTomorrow = allPrayers.first(where: { $0.name == "Fajr" }),
                   let fajrTomorrowDate = date(for: fajrTomorrow.time, basedOn: tomorrow) {
                    return now >= fajrTomorrowDate
                }
                return false
            }
        }
        return false
    }

    func findNextPrayerAndTime(allPrayers prayers: [Prayer]) -> (Prayer, Date)? {
        let now = Date()
        
        for prayer in prayers {
            guard let prayerDate = date(for: prayer.time, basedOn: now) else { continue }
            
            if now < prayerDate {
                return (prayer, prayerDate)
            }
        }

        if let fajr = prayers.first(where: { $0.name == "Fajr" }),
           let fajrToday = date(for: fajr.time, basedOn: now) {
            if let fajrTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: fajrToday) {
                return (fajr, fajrTomorrow)
            }
        }
        return nil
    }

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

    func isDaytime(prayers: [Prayer], currentTime: Date = Date()) -> Bool {
        guard let fajr = prayers.first(where: { $0.name == "Fajr" }),
              let maghrib = prayers.first(where: { $0.name == "Maghrib" }) else {
            return true
        }

        guard let fajrDate = date(for: fajr.time, basedOn: currentTime),
              let maghribDate = date(for: maghrib.time, basedOn: currentTime) else {
            return true
        }

        return currentTime >= fajrDate && currentTime < maghribDate
    }
}
