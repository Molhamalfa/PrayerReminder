//
//  PrayerTimeResponse.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//


// MARK: - API Response Models

// Reverted to Aladhan's top-level response structure
struct PrayerTimesResponse: Codable {
    let data: PrayerData
}

// Reverted to Aladhan's PrayerData structure
struct PrayerData: Codable {
    let timings: [String: String]
    // Aladhan's 'data' also contains 'date' and 'meta', but we only need 'timings' for this app's current functionality.
    // If you need date or meta information from Aladhan, you would add corresponding Codable properties here.
}

extension Dictionary where Key == String, Value == String {
    func filteredPrayers() -> [Key: Value] {
        let requiredKeys = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        return self.filter { requiredKeys.contains($0.key) }
    }
}
