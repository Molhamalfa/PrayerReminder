//
//  NextPrayerTimeView.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import SwiftUI

struct NextPrayerTimerView: View {
    let currentActivePrayer: Prayer?
    let nextPrayerName: String
    let timeUntilNextPrayer: String
    let statusIcon: (Prayer) -> String
    let statusColor: (Prayer) -> Color
    let statusLabel: (Prayer) -> String
    let togglePrayerStatus: (Prayer, PrayerStatus) -> Void
    let isDay: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(nextPrayerName)
                .font(.headline)
                .foregroundColor(isDay ? .secondary : .white.opacity(0.7))
            
            Text(timeUntilNextPrayer)
                .font(.system(size: 60, weight: .bold))
                .monospacedDigit()
                .foregroundColor(isDay ? .primary : .white)

            if let activePrayer = currentActivePrayer {
                HStack {
                    Image(systemName: statusIcon(activePrayer))
                        .foregroundColor(statusColor(activePrayer))
                    Text(NSLocalizedString(activePrayer.name, comment: ""))
                        .font(.subheadline)
                        .foregroundColor(isDay ? .primary : .white)
                    Spacer()
                    
                    if activePrayer.status == .upcoming {
                        Button(action: {
                            // FIX: Use corrected togglePrayerStatus closure
                            togglePrayerStatus(activePrayer, .completed)
                        }) {
                            Text(NSLocalizedString("Prayed", comment: ""))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .font(.caption.bold())
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(
            Group {
                if isDay {
                    Color.gray.opacity(0.2)
                } else {
                    LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.1), Color.black.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        )
        .cornerRadius(12)
        .shadow(radius: 0)
        .padding(.horizontal)
    }
}
