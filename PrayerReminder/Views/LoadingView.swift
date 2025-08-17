//
//  LoadingView.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import SwiftUI

struct LoadingView: View {
    var title: String
    // NEW: State to determine if loading has failed.
    var hasFailed: Bool
    // NEW: A closure to be executed when the user taps the retry button.
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            if hasFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                Text(NSLocalizedString("Failed to load data.", comment: "Error message when data loading fails"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                // Show the retry button only if an onRetry action has been provided.
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        Label(NSLocalizedString("Try Again", comment: "Button title to retry a failed action"), systemImage: "arrow.clockwise")
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
    LoadingView(title: "", hasFailed: true, onRetry: {
        print("Retry tapped!")
    })
}
