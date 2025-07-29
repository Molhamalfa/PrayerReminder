//
//  LoadingView.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//


import SwiftUI

struct LoadingView: View {
    var title: String // This title is passed from PrayerReminderView, already localized there

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)

            Text(title) // Already localized from where it's passed (PrayerReminderView)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoadingView(title: NSLocalizedString("Loading...", comment: "")) // Localized for preview
}
