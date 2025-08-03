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
                DynamicSkyBackgroundView(prayers: viewModel.prayers, isDay: viewModel.isDay)
                    .ignoresSafeArea()

                // FIX: Wrap the entire content VStack in a ScrollView
                ScrollView { // This ScrollView will make the entire content scrollable
                    VStack { // This VStack holds the settings button row and the main content
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

                        if viewModel.isLoading || viewModel.isLanguageChanging {
                            Spacer()
                            LoadingView(title: NSLocalizedString("Loading...", comment: "Loading indicator message"))
                            Spacer()
                        } else {
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
                                
                                PrayerStatusSummaryView(prayers: viewModel.prayers, isDay: viewModel.isDay)
                                
                                PrayerCalendarView(isDay: viewModel.isDay)
                                    .environmentObject(viewModel)
                            }
                            .padding(.top, 20)
                        }
                    }
                    // The .refreshable and .background modifiers should be on the ScrollView
                    // The .refreshable will now apply to the entire scrollable content
                }
                .refreshable {
                    await viewModel.refreshPrayerTimes()
                }
                .background(Color.clear) // Keep background clear for DynamicSkyBackgroundView
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onAppear {
            print("🚀 PrayerReminderView: onAppear called.")
            viewModel.requestLocation()
        }
    }
}
