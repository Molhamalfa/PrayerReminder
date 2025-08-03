//
//  PrayerDataStore.swift
//  PrayerReminder
//
//  Created by Mac on 25.07.2025.
//

import Foundation

class PrayerDataStore {
    // Changed key to reflect storing an array of daily data
    private let allSavedPrayersKey = "allSavedPrayersHistory"

    // Saves the current list of prayers along with today's date
    func savePrayers(_ prayers: [Prayer]) {
        let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let currentDayData = SavedPrayerData(date: todayString, prayers: prayers)
        
        // Load existing history
        var history = loadAllSavedPrayerData() ?? []
        
        // Check if data for today already exists in history
        if let index = history.firstIndex(where: { $0.date == todayString }) {
            // Update existing entry
            history[index] = currentDayData
            print("✅ DataStore: Updated saved prayers for today: \(todayString)")
        } else {
            // Add new entry for today
            history.append(currentDayData)
            print("✅ DataStore: Added new saved prayers for today: \(todayString)")
        }
        
        do {
            let encoded = try JSONEncoder().encode(history)
            UserDefaults.standard.set(encoded, forKey: allSavedPrayersKey)
            print("✅ DataStore: Saved updated prayer history to UserDefaults. Total days: \(history.count)")
        } catch {
            print("❌ DataStore: Failed to encode prayer history: \(error)")
        }
    }
    
    // NEW: Loads saved prayers for today from UserDefaults
    func loadSavedPrayersForToday() -> SavedPrayerData? {
        let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let history = loadAllSavedPrayerData(),
           let currentDayData = history.first(where: { $0.date == todayString }) {
            print("✅ DataStore: Loaded saved prayers for today: \(currentDayData.date). Count: \(currentDayData.prayers.count)")
            return currentDayData
        } else {
            print("ℹ️ DataStore: No saved prayers found for today: \(todayString).")
            return nil
        }
    }
    
    // NEW: Loads all historical prayer data from UserDefaults
    func loadAllSavedPrayerData() -> [SavedPrayerData]? {
        guard let data = UserDefaults.standard.data(forKey: allSavedPrayersKey) else {
            print("ℹ️ DataStore: No historical data found in UserDefaults for key '\(allSavedPrayersKey)'.")
            return nil
        }
        
        do {
            let decoded = try JSONDecoder().decode([SavedPrayerData].self, from: data)
            print("✅ DataStore: Loaded \(decoded.count) days of historical prayer data.")
            return decoded
        } catch {
            print("❌ DataStore: Failed to decode historical saved prayers: \(error)")
            return nil
        }
    }
    
    // Clears all saved prayer data (useful for testing or future reset features)
    func clearSavedPrayers() {
        UserDefaults.standard.removeObject(forKey: allSavedPrayersKey)
        print("🗑️ DataStore: Cleared all saved prayer data from UserDefaults.")
    }
}
