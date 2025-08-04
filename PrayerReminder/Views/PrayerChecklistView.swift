//
//  PrayerChecklistView.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//
import SwiftUI

struct PrayerChecklistView: View {
    let prayers : [Prayer]
    let hasPrayerTimePassed: (Prayer) -> Bool
    let isPrayerCurrentlyActive: (Prayer) -> Bool
    let statusIcon: (Prayer) -> String
    let statusColor: (Prayer) -> Color
    let statusLabel: (Prayer) -> String
    let togglePrayerStatus: (Prayer, PrayerStatus) -> Void
    let hasPrayerWindowEnded: (Prayer) -> Bool
    let isDay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey("Today's Prayers"), systemImage: "checklist")
                .font(.title2.bold())
                .padding(.bottom, 4)
                .foregroundColor(isDay ? .primary : .white.opacity(0.9))

            // FIX: Ensure all PrayerListCell calls use the correct parameters
            ForEach(prayers) { prayer in
                // The PrayerListCell itself handles the display logic for "Sunrise" and the "Prayed" button.
                // We no longer need this complex conditional check here.
                PrayerListCell(
                    prayer: prayer,
                    hasPrayerTimePassed: hasPrayerTimePassed,
                    isPrayerCurrentlyActive: isPrayerCurrentlyActive,
                    statusIcon: statusIcon,
                    statusColor: statusColor,
                    statusLabel: statusLabel,
                    togglePrayerStatus: togglePrayerStatus,
                    hasPrayerWindowEnded: hasPrayerWindowEnded,
                    isDay: isDay
                )
            }
        }
        .padding()
    }
}
