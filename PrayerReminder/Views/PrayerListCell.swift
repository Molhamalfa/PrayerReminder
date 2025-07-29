//
//  PrayerListCell.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import SwiftUI

struct PrayerListCell: View {
    let prayer: Prayer
    let hasPrayerTimePassed: (Prayer) -> Bool
    let isPrayerCurrentlyActive: (Prayer) -> Bool
    let statusIcon: (Prayer) -> String
    let statusColor: (Prayer) -> Color
    let statusLabel: (Prayer) -> String
    let togglePrayerStatus: (Prayer, PrayerStatus) -> Void
    let hasPrayerWindowEnded: (Prayer) -> Bool
    let isDay: Bool // NEW: Receive isDay from ViewModel

    var body: some View {
        let isActive = isPrayerCurrentlyActive(prayer)
        let isMissed = prayer.status == .missed

        VStack(alignment: .leading) {
            HStack {
                Image(systemName: statusIcon(prayer))
                    .foregroundColor(statusColor(prayer))
                Text(prayer.name)
                    .font(.headline)
                    .foregroundColor(isDay ? .primary : .white.opacity(0.9)) // Adjust text color
                Spacer()
                Text(prayer.time)
                    .font(.subheadline)
                    .foregroundColor(isDay ? .gray : .white.opacity(0.7)) // Adjust text color
                Text(statusLabel(prayer))
                    .foregroundColor(statusColor(prayer))
                    .font(.subheadline)
            }

            if prayer.name != "Sunrise" {
                HStack(spacing: 16) {
                    Button(action: {
                        togglePrayerStatus(prayer, .completed)
                    }) {
                        Label(NSLocalizedString("Prayed", comment: ""), systemImage: "checkmark")
                            .padding(6)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .disabled(!isActive || isMissed) // Disable if not active or already missed
                }
                .font(.caption)
            }
        }
        .padding()
        // FIX: Conditional background for day/night
        .background(
            Group {
                if isDay {
                    Color(.systemGray6)
                } else {
                    LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.black.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        )
        .cornerRadius(12)
    }
}
