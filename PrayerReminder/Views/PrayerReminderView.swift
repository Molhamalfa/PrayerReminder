//
//  ContentView.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import SwiftUI

struct PrayerReminderView: View {
    @EnvironmentObject var viewModel: PrayerReminderViewModel

    var body: some View {
        NavigationView {
            ZStack {
                // The dynamic background should be visible even when loading.
                DynamicSkyBackgroundView(prayers: viewModel.prayers, isDay: viewModel.isDay)
                    .ignoresSafeArea()

                // Main content area
                if viewModel.isLoading || viewModel.isLanguageChanging || viewModel.loadingFailed {
                    LoadingView(
                        title: NSLocalizedString("Loading...", comment: "Loading indicator message"),
                        hasFailed: viewModel.loadingFailed,
                        errorMessage: viewModel.errorMessage,
                        onRetry: {
                            viewModel.loadInitialData()
                        }
                    )
                } else {
                    // Main content ScrollView, shown only when loading is complete and not failed.
                    ScrollView {
                        VStack {
                            HStack {
                                Spacer()
                                NavigationLink(destination: SettingsView()) {
                                    Image(systemName: "gear")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                        .padding(15)
                                }
                            }
                            .padding(.top, 5)

                            VStack(spacing: 20) {
                                NextPrayerTimerView(
                                    currentActivePrayer: viewModel.currentActivePrayer,
                                    nextPrayerName: viewModel.nextPrayerName,
                                    timeUntilNextPrayer: viewModel.timeUntilNextPrayer,
                                    statusIcon: viewModel.statusIcon,
                                    statusColor: viewModel.statusColor,
                                    statusLabel: viewModel.statusLabel,
                                    togglePrayerStatus: viewModel.togglePrayerStatus,
                                    isDay: viewModel.isDay
                                )
                                
                                // UPDATED: Pass the isPrayerCurrentlyActive function to the summary view.
                                PrayerStatusSummaryView(
                                    prayers: viewModel.prayers,
                                    isDay: viewModel.isDay,
                                    isPrayerCurrentlyActive: viewModel.isPrayerCurrentlyActive
                                )
                                
                                PrayerCalendarView(isDay: viewModel.isDay)
                                    .environmentObject(viewModel)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .refreshable {
                        await viewModel.refreshPrayerTimes()
                    }
                    .background(Color.clear)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadInitialData()
        }
    }
}
