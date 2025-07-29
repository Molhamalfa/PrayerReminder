//
//  PrayerReminderApp.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import SwiftUI
import UserNotifications

@main
struct PrayerReminderApp: App {
    @StateObject private var viewModel = PrayerReminderViewModel()
    
    // This @AppStorage property is the source of truth for the selected language
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode: String = "en"
    
    // This UUID is used to force a complete redraw of the root view hierarchy
    @State private var rootViewID = UUID()

    // Create an instance of the NotificationDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            PrayerReminderView()
                .environmentObject(viewModel)
                // Use the rootViewID to force a complete redraw of PrayerReminderView and its children
                // when selectedLanguageCode changes.
                .id(rootViewID)
                // Explicitly set the locale environment value for all subviews
                .environment(\.locale, Locale(identifier: selectedLanguageCode))
                // Observe changes to selectedLanguageCode and update rootViewID
                .onChange(of: selectedLanguageCode) { oldValue, newLanguageCode in
                    // When language changes, update the rootViewID to force a full UI rebuild
                    rootViewID = UUID()
                    print("🌐 App: Root View ID updated, forcing full UI rebuild for language: \(newLanguageCode)")
                    
                    // Optional: Add a small delay to allow SwiftUI to process the environment change
                    // before potentially triggering other updates. This can sometimes help with glitches.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Optionally, you could trigger a viewModel refresh here as well,
                        // but `applyLanguageChange` in ViewModel already does that.
                        print("🌐 App: Short delay completed after language change.")
                    }
                }
                .onAppear {
                    // Assign the viewModel to the AppDelegate when the app appears
                    appDelegate.viewModel = viewModel
                    UNUserNotificationCenter.current().delegate = appDelegate // Set delegate for notifications
                    print("🚀 App: PrayerReminderApp did appear. Initial language: \(selectedLanguageCode)")
                }
        }
    }
}

// MARK: - AppDelegate for UNUserNotificationCenterDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Hold a reference to the ViewModel to interact with it from notification delegate methods
    weak var viewModel: PrayerReminderViewModel?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request notification authorization on app launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ AppDelegate: Notification permission granted.")
            } else if let error = error {
                print("❌ AppDelegate: Notification permission error: \(error.localizedDescription)")
            } else {
                print("🚫 AppDelegate: Notification permission denied.")
            }
        }
        
        // Set the UNUserNotificationCenter delegate to self
        UNUserNotificationCenter.current().delegate = self
        
        // Register the custom notification category defined in PrayerNotificationScheduler
        PrayerNotificationScheduler.shared.registerNotificationCategory()
        
        return true
    }

    // Handle notification actions (e.g., "Prayed" button)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let prayerName = userInfo["prayerName"] as? String ?? "Unknown Prayer"
        
        switch response.actionIdentifier {
        case PrayerNotificationScheduler.prayedActionIdentifier:
            print("🔔 Notification Action: 'Prayed' button tapped for \(prayerName).")
            // Find the prayer and update its status via the ViewModel
            if let viewModel = viewModel, let prayerToUpdate = viewModel.prayers.first(where: { $0.name == prayerName }) {
                viewModel.togglePrayerStatus(for: prayerToUpdate, to: .completed)
                print("Status of \(prayerName) updated to completed.")
            } else {
                print("Failed to access ViewModel from AppDelegate or find prayer named \(prayerName) to update.")
            }
            
        case UNNotificationDefaultActionIdentifier:
            print("🔔 Notification Action: Notification body tapped for \(prayerName).")
            
        case UNNotificationDismissActionIdentifier:
            print("🔔 Notification Action: Notification dismissed for \(prayerName).")
            
        default:
            break
        }
        
        completionHandler()
    }
    
    // Show notification while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 Notification Action: Notification will present in foreground: \(notification.request.content.title)")
        completionHandler([.banner, .sound, .badge])
    }
}
