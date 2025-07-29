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
    let isDay: Bool // NEW: Receive isDay from ViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text(nextPrayerName)
                .font(.headline)
                .foregroundColor(isDay ? .secondary : .white.opacity(0.7)) // Adjust text color for night
            
            Text(timeUntilNextPrayer)
                .font(.system(size: 60, weight: .bold))
                .monospacedDigit()
                .foregroundColor(isDay ? .primary : .white) // Adjust text color for night

            if let activePrayer = currentActivePrayer {
                HStack {
                    Image(systemName: statusIcon(activePrayer))
                        .foregroundColor(statusColor(activePrayer))
                    Text(NSLocalizedString(activePrayer.name, comment: ""))
                        .font(.subheadline)
                        .foregroundColor(isDay ? .primary : .white) // Adjust text color for night
                    Spacer()
                    
                    if activePrayer.status == .upcoming {
                        Button(action: {
                            togglePrayerStatus(activePrayer, .completed)
                        }) {
                            Label(NSLocalizedString("Prayed", comment: "Button to mark prayer as prayed"), systemImage: "checkmark")
                                .padding(.vertical, 6)
                                .padding(.horizontal, 15)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(activePrayer.status != .upcoming)
                    } else if activePrayer.status == .completed {
                        Text(NSLocalizedString("Prayed", comment: "Status text for completed prayer"))
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 15)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(10)
                    } else if activePrayer.status == .missed {
                        Text(NSLocalizedString("Missed", comment: "Status text for missed prayer"))
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 15)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        // FIX: Conditional background for day/night
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

#Preview {
    NextPrayerTimerView(
        currentActivePrayer: Prayer(name: "Dhuhr", time: "13:11", status: .upcoming),
        nextPrayerName: NSLocalizedString("Time until Asr", comment: ""),
        timeUntilNextPrayer: "02h 30m",
        statusIcon: { prayer in
            if prayer.name == "Dhuhr" { return "hourglass.tophalf.filled" }
            return "hourglass"
        },
        statusColor: { prayer in
            if prayer.name == "Dhuhr" { return .blue }
            return .gray
        },
        statusLabel: { prayer in
            if prayer.status == .upcoming { return NSLocalizedString("Active", comment: "") }
            if prayer.status == .completed { return NSLocalizedString("Prayed", comment: "") }
            if prayer.status == .missed { return NSLocalizedString("Missed", comment: "") }
            return ""
        },
        togglePrayerStatus: { prayer, status in
            print("Toggled \(prayer.name) to \(status.rawValue)")
        },
        isDay: false // Set to false for night mode preview
    )
    .environment(\.locale, Locale(identifier: "en"))
}
