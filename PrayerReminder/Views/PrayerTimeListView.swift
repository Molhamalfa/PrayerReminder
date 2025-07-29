//
//  PrayerTimeListView.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//



import SwiftUI

struct PrayerTimeListView: View {
     var prayers: [Prayer]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(LocalizedStringKey("Prayer Times"), image: "mosque")
                .font(.title2.bold())
            ForEach(prayers) { prayer in
                HStack {
                    // Localize the prayer name here
                    Text(String(format: NSLocalizedString("%@:", comment: ""), NSLocalizedString(prayer.name, comment: "")))
                        .fontWeight(.medium)
                    Spacer()
                    Text(prayer.time)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12) // UPDATED: Changed from 16 to 12 for consistency
        .padding(.horizontal)
    }
}
