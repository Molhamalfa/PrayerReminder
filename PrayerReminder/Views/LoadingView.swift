//
//  LoadingView.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import SwiftUI

struct LoadingView: View {
    var title: String
    var hasFailed: Bool
    var errorMessage: String? // UPDATED: To hold a specific error message
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            if hasFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                // UPDATED: Display specific error message if available, otherwise a generic one
                Text(errorMessage ?? NSLocalizedString("Failed to load data.", comment: "Generic error message"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        Label(NSLocalizedString("Try Again", comment: "Retry button"), systemImage: "arrow.clockwise")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .font(.headline)
                            .cornerRadius(10)
                    }
                }
                
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    // Preview for the loading state
    LoadingView(title: NSLocalizedString("Loading...", comment: ""), hasFailed: false, onRetry: nil)
}

#Preview("Failed State") {
    // Preview for the failed state with a retry button
    LoadingView(title: "", hasFailed: true, errorMessage: "The server is currently unavailable.", onRetry: {
        print("Retry tapped!")
    })
}
