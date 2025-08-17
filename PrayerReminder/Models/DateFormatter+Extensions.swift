//
//  DateFormatter+Extensions.swift
//  PrayerReminder
//
//  Created by Mac on 28.07.2025.
//

import Foundation

extension DateFormatter {
    /// A shared, static date formatter for creating consistent, non-localized date strings for use as database keys.
    /// Using a fixed format like "yyyy-MM-dd" ensures that the key for a specific date is always the same,
    /// regardless of the user's device region or locale settings.
    static let databaseKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Using a consistent timezone like UTC/GMT is crucial to prevent the date from shifting
        // based on the user's current location.
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        // The POSIX locale is essential for ensuring the date format is interpreted literally.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
