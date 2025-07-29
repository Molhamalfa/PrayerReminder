////
//  PrayerStatusSummaryView.swift
//  PrayerReminder
//
//  Created by Mac on 26.07.2025.
//

import SwiftUI

struct PrayerStatusSummaryView: View {
    let prayers: [Prayer]
    let isDay: Bool

    private var completedPrayers: [Prayer] {
        prayers.filter { $0.status == .completed && $0.name != "Sunrise" }
    }

    private var missedPrayers: [Prayer] {
        prayers.filter { $0.status == .missed && $0.name != "Sunrise" }
    }

    private var upcomingPrayers: [Prayer] {
        prayers.filter { $0.status == .upcoming }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(LocalizedStringKey("Today's Prayer Summary"))
                .font(.title2.bold())
                .foregroundColor(isDay ? Color.blue.opacity(0.8) : Color.blue.opacity(0.7))
                .padding(.horizontal)

            HStack(alignment: .top, spacing: 15) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey("Prayed Prayers:"))
                        .font(.headline)
                        .foregroundColor(isDay ? Color.green.opacity(0.8) : Color.green.opacity(0.7))
                    
                    if !completedPrayers.isEmpty {
                        ForEach(completedPrayers) { prayer in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(NSLocalizedString(prayer.name, comment: ""))
                                    .foregroundColor(isDay ? .black.opacity(0.8) : .white) // FIX: Adjusted color
                                Spacer()
                                Text(prayer.time)
                                    .font(.caption)
                                    .foregroundColor(isDay ? .gray : .white.opacity(0.6))
                            }
                        }
                    } else {
                        Text(LocalizedStringKey("No prayers marked as prayed yet."))
                            .font(.subheadline)
                            .foregroundColor(isDay ? Color.black.opacity(0.6) : Color.white.opacity(0.5))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if isDay {
                            Color.white.opacity(0.8)
                        } else {
                            LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.black.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                )
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)


                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey("Missed Prayers:"))
                        .font(.headline)
                        .foregroundColor(isDay ? Color.red.opacity(0.8) : Color.red.opacity(0.7))

                    if !missedPrayers.isEmpty {
                        ForEach(missedPrayers) { prayer in
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(NSLocalizedString(prayer.name, comment: ""))
                                    .foregroundColor(isDay ? .black.opacity(0.8) : .white) // FIX: Adjusted color
                                Spacer()
                                Text(prayer.time)
                                    .font(.caption)
                                    .foregroundColor(isDay ? .gray : .white.opacity(0.6))
                            }
                        }
                    } else {
                        Text(LocalizedStringKey("No prayers missed yet."))
                            .font(.subheadline)
                            .foregroundColor(isDay ? Color.black.opacity(0.6) : Color.white.opacity(0.5))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if isDay {
                            Color.white.opacity(0.8)
                        } else {
                            LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.black.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                )
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey("Upcoming Prayers:"))
                    .font(.headline)
                    .foregroundColor(isDay ? Color.blue.opacity(0.8) : Color.blue.opacity(0.7))

                if !upcomingPrayers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(upcomingPrayers) { prayer in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "hourglass")
                                            .foregroundColor(.blue)
                                        Text(NSLocalizedString(prayer.name, comment: ""))
                                            .font(.headline)
                                            .foregroundColor(isDay ? .black.opacity(0.8) : .white) // FIX: Adjusted color
                                    }
                                    Text(prayer.time)
                                        .font(.subheadline)
                                        .foregroundColor(isDay ? .gray : .white.opacity(0.7))
                                }
                                .padding()
                                .background(isDay ? Color.blue.opacity(0.1) : Color.blue.opacity(0.15))
                                .cornerRadius(8)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                } else {
                    Text(LocalizedStringKey("All prayers completed or missed for today."))
                        .font(.subheadline)
                        .foregroundColor(isDay ? Color.black.opacity(0.6) : Color.white.opacity(0.5))
                }
            }
            .padding()
            .background(
                Group {
                    if isDay {
                        Color.white.opacity(0.8)
                    } else {
                        LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.black.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
            )
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

#Preview {
    ZStack {
        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        PrayerStatusSummaryView(
            prayers: [
                Prayer(name: "Fajr", time: "04:30", status: .completed),
                Prayer(name: "Sunrise", time: "06:00", status: .upcoming),
                Prayer(name: "Dhuhr", time: "13:00", status: .upcoming),
                Prayer(name: "Asr", time: "17:00", status: .missed),
                Prayer(name: "Maghrib", time: "19:00", status: .upcoming),
                Prayer(name: "Isha", time: "21:00", status: .upcoming)
            ],
            isDay: false
        )
    }
}
