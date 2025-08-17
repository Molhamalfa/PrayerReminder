//
//  SettingsView.swift
//  PrayerReminder
//
//  Created by Mac on 25.07.2025.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = true
    @AppStorage("userReminderIntervalInMinutes") private var userReminderIntervalInMinutes: Int = 10
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode: String = "en"
    
    @EnvironmentObject var viewModel: PrayerReminderViewModel

    let reminderIntervalOptions = [1, 5, 10, 15, 30]

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("Reminders"))) {
                Toggle(LocalizedStringKey("Enable Prayer Reminders"), isOn: $reminderEnabled)
                    .onChange(of: reminderEnabled) { oldValue, newValue in
                        // CORRECTED: Call the new, correct function name.
                        viewModel.handleReminderSettingsChange()
                    }

                if reminderEnabled {
                    Picker(selection: $userReminderIntervalInMinutes) {
                        ForEach(reminderIntervalOptions, id: \.self) { minutes in
                            Text(String(format: NSLocalizedString("Remind every %d minutes", comment: ""), minutes))
                                .tag(minutes)
                        }
                    } label: {
                        Text(LocalizedStringKey("Reminder Interval"))
                    }
                    .pickerStyle(.menu)
                    .onChange(of: userReminderIntervalInMinutes) { oldValue, newValue in
                        // CORRECTED: Call the new, correct function name.
                        viewModel.handleReminderSettingsChange()
                    }
                }
            }

            Section(header: Text(LocalizedStringKey("Language"))) {
                Picker(LocalizedStringKey("App Language"), selection: $selectedLanguageCode) {
                    Text(LocalizedStringKey("English")).tag("en")
                    Text(LocalizedStringKey("العربية")).tag("ar")
                    Text(LocalizedStringKey("Türkçe")).tag("tr")
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguageCode) { oldValue, newLanguageCode in
                    viewModel.applyLanguageChange(newLanguageCode)
                }

                Text(LocalizedStringKey("If you notice any glitches while changing languages, please try exiting the app completely and re-entering after changing the language."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 5)
            }
        }
        .navigationTitle(LocalizedStringKey("Settings"))
    }
}


#Preview {
    SettingsView()
        .environmentObject(PrayerReminderViewModel())
}
