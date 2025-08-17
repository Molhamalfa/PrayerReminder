//
//  PrayerReminderModel.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import Foundation
import CoreLocation

/// Represents the status of a prayer.
/// Conforms to `Codable` to allow for easy encoding to and from JSON for storage.
enum PrayerStatus: String, Codable {
    case completed
    case missed
    case upcoming
}

/// Represents a single prayer with its name, time, and current status.
/// Conforms to `Identifiable`, `Codable`, and `Equatable` for use in SwiftUI lists,
/// for data persistence, and for easy comparison.
struct Prayer: Identifiable, Codable, Equatable {
    // The name of the prayer serves as its unique ID (e.g., "Fajr", "Dhuhr").
    var id: String { name }
    let name: String
    let time: String
    var status: PrayerStatus
}

/// A container struct that holds an array of `Prayer` objects for a specific date.
/// This is the object that gets stored in and retrieved from CloudKit.
/// The `date` string acts as the unique identifier for a day's prayer data.
struct SavedPrayerData: Codable, Identifiable {
    // The date string (e.g., "8/17/25") serves as the unique ID for this record.
    var id: String { date }
    let date: String
    let prayers: [Prayer]
}
