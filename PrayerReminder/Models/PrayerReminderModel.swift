//
//  PrayerReminderModel.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//


// MARK: - Model

import Foundation
import CoreLocation

enum PrayerStatus: String, Codable {
    
    case completed
    case missed
    case upcoming
    
    
}


struct Prayer: Identifiable, Codable, Equatable {
    var id: String { name } // Name is unique
    let name: String
    let time: String
    var status: PrayerStatus
}



struct SavedPrayerData: Codable {
    let date: String // e.g. "2025-07-24"
    let prayers: [Prayer]
}
