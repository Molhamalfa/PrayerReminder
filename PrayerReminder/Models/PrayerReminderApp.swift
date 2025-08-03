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
                    print("🌐 App: Root View ID updated, forcing UI rebuild for language change.")
                }
        }
    }
}


// A custom AppDelegate to handle notifications
// FIX: Concurrency error. UNUserNotificationCenterDelegate is nonisolated.
//      The `userNotificationCenter` methods are not guaranteed to be called on the main thread,
//      and they can't be implicitly @MainActor-isolated in Swift 6.
//      Making the class `nonisolated` fixes this. We then use a Task to explicitly
//      jump to the main actor when interacting with the @MainActor-isolated ViewModel.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    
    // Hold a reference to the ViewModel
    // Note: We cannot use @EnvironmentObject here as AppDelegate is not part of the SwiftUI view hierarchy.
    // The viewModel is injected when the app launches in didFinishLaunchingWithOptions
    var viewModel: PrayerReminderViewModel?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("🔔 Notification permission granted: \(granted)")
            if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
            if granted {
                // Register the notification category for the "Prayed" action
                PrayerNotificationScheduler.shared.registerNotificationCategory()
            }
        }
        
        // Set this class as the delegate for UNUserNotificationCenter
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // FIX: Removed @nonisolated. The protocol methods are already nonisolated,
    // and AppDelegate is not an actor, so this modifier is not needed and causes a compiler error.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        guard let prayerName = response.notification.request.content.userInfo["prayerName"] as? String else {
            print("🔔 Notification Action: Prayer name not found in user info.")
            completionHandler()
            return
        }
        
        switch response.actionIdentifier {
        case PrayerNotificationScheduler.prayedActionIdentifier:
            print("🔔 Notification Action: 'Prayed' button tapped for \(prayerName).")
            // Find the prayer and update its status via the ViewModel
            // FIX: Use a Task to explicitly run on the main actor.
            Task { @MainActor in
                if let prayerToUpdate = self.viewModel?.prayers.first(where: { $0.name == prayerName }) {
                    self.viewModel?.togglePrayerStatus(for: prayerToUpdate, to: .completed)
                    print("Status of \(prayerName) updated to completed.")
                } else {
                    print("Failed to access ViewModel from AppDelegate or find prayer named \(prayerName) to update.")
                }
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
    // FIX: Removed @nonisolated. The protocol methods are already nonisolated,
    // and AppDelegate is not an actor, so this modifier is not needed and causes a compiler error.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 Notification Action: Notification will present in foreground: \(notification.request.content.title)")
        completionHandler([.banner, .sound, .badge])
    }
}
