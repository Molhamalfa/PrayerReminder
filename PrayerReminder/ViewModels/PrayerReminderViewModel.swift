//
//  PrayerReminderViewModel.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//

import SwiftUI
import Combine
import CoreLocation
import UserNotifications

@MainActor
class PrayerReminderViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate, Identifiable {
    @AppStorage("userReminderIntervalInMinutes") private var userReminderIntervalInMinutes: Int = 10
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = true
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode: String = "en"
    @AppStorage("selectedCalculationMethod") private var selectedCalculationMethod: Int = 2
    @AppStorage("lastFetchedDate") private var lastFetchedDate: String = ""

    @Published var lastFetchedLatitude: CLLocationDegrees?
    @Published var lastFetchedLongitude: CLLocationDegrees?
    
    @Published var isLoading = true
    @Published var loadingFailed = false
    @Published var isLanguageChanging = false
    @Published var refreshID = UUID()

    @Published var isDay: Bool = true {
        didSet {
            print("🌓 ViewModel: isDay didSet: \(isDay ? "Day" : "Night")")
        }
    }

    private let dataStore = PrayerDataStore()
    private let timeLogicHelper = PrayerTimeLogicHelper()
    private let locationManager = CLLocationManager()
    private let apiService = AladhanAPIService()

    @Published var prayers: [Prayer] = [] {
        didSet {
            dataStore.savePrayers(prayers)
            updatePrayerWindowStatus()
            updateTimeUntilNextPrayer()
            isDay = timeLogicHelper.isDaytime(prayers: prayers)
            updateHistoricalData(for: prayers)
        }
    }
    
    // MARK: - Prayer Status Properties

    // The name of the next upcoming prayer.
    @Published var nextPrayerName: String = ""
    
    // The time remaining until the next prayer.
    @Published var timeUntilNextPrayer: String = ""
    
    // The currently active prayer.
    var currentActivePrayer: Prayer? {
        let prayersForActiveCheck = prayers.filter { $0.name != "Sunrise" }
        // FIX: Removed the extra `allPrayers` argument to match the helper function.
        return prayersForActiveCheck.first { timeLogicHelper.isPrayerCurrentlyActive(for: $0, allPrayers: prayersForActiveCheck) }
    }

    private var prayerStatusCancellable: AnyCancellable?
    private var timerCancellable: AnyCancellable?

    override init() {
        super.init()
        setupNotificationDelegate()
        setupLocationManager()
        loadInitialData()
        startTimer()
    }

    // MARK: - Initialization & Data Loading
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
        PrayerNotificationScheduler.shared.registerNotificationCategory()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func loadInitialData() {
        let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        
        // FIX 1: Refactored to use `loadAllSavedPrayerData()` and filter for today,
        // which avoids the `loadSavedPrayersForToday()` method which was causing a `no member` error.
        if let savedData = dataStore.loadAllSavedPrayerData()?.first(where: { $0.date == todayString }) {
            self.prayers = savedData.prayers
            self.isLoading = false
            self.isDay = timeLogicHelper.isDaytime(prayers: savedData.prayers)
        } else {
            // Data not available, request location to fetch new times.
            requestLocation()
        }
    }

    // MARK: - Location Management

    func requestLocation() {
        print("📍 ViewModel: Requesting location authorization.")
        locationManager.requestWhenInUseAuthorization()
    }
    
    // FIX 2: Added `nonisolated` to satisfy the protocol requirement for Swift 6.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ ViewModel: Location authorization granted. Starting to update location.")
                manager.startUpdatingLocation()
            case .denied, .restricted:
                print("❌ ViewModel: Location access denied or restricted. Using fallback location.")
                // FIX 3: Wrapped the async call in a `Task` to run it in a concurrency context.
                await self.fetchPrayerTimes(latitude: 41.0082, longitude: 28.9784) // Fallback to Istanbul
            case .notDetermined:
                print("⏳ ViewModel: Location authorization not determined.")
                self.isLoading = true
            @unknown default:
                print("⚠️ ViewModel: Unknown authorization status.")
                self.isLoading = true
            }
        }
    }
    
    // FIX 2: Added `nonisolated` to satisfy the protocol requirement for Swift 6.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else { return }
            
            // Stop updating to save battery
            manager.stopUpdatingLocation()
            
            self.lastFetchedLatitude = location.coordinate.latitude
            self.lastFetchedLongitude = location.coordinate.longitude
            
            print("📍 ViewModel: New location received. Latitude: \(location.coordinate.latitude), Longitude: \(location.coordinate.longitude)")
            
            // Check if a fetch is needed
            let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            if lastFetchedDate != todayString || lastFetchedLatitude == nil {
                await self.fetchPrayerTimes(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            } else {
                self.isLoading = false
            }
        }
    }
    
    // FIX 2: Added `nonisolated` to satisfy the protocol requirement for Swift 6.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ ViewModel: Failed to get user location: \(error.localizedDescription)")
            // FIX 3: Wrapped the async call in a `Task` to run it in a concurrency context.
            await self.fetchPrayerTimes(latitude: 41.0082, longitude: 28.9784) // Fallback to Istanbul
            self.isLoading = false
            self.loadingFailed = true
        }
    }

    // MARK: - API & Data Fetching

    func fetchPrayerTimes(latitude: Double, longitude: Double) async {
        print("🌐 ViewModel: Fetching prayer times for \(latitude), \(longitude) using method \(selectedCalculationMethod)...")
        self.isLoading = true
        self.loadingFailed = false
        
        do {
            let fetchedPrayers = try await apiService.fetchPrayerTimes(latitude: latitude, longitude: longitude, method: selectedCalculationMethod)
            self.prayers = fetchedPrayers
            self.lastFetchedDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            self.isLoading = false
            PrayerNotificationScheduler.shared.scheduleNotifications(for: prayers)
            handleReminderRepeats()
            print("✅ ViewModel: Successfully fetched prayer times.")
        } catch {
            print("❌ ViewModel: Failed to fetch prayer times: \(error.localizedDescription)")
            self.isLoading = false
            self.loadingFailed = true
        }
    }

    func refreshPrayerTimes() async {
        guard let lat = lastFetchedLatitude, let lon = lastFetchedLongitude else {
            requestLocation()
            return
        }
        await fetchPrayerTimes(latitude: lat, longitude: lon)
    }

    // MARK: - Timer & UI Updates
    
    private func startTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateTimeUntilNextPrayer()
                self.updatePrayerWindowStatus()
            }
    }

    private func updateTimeUntilNextPrayer() {
        let prayersForNextPrayer = prayers.filter { $0.status == .upcoming }
        
        // FIX: This now correctly unpacks the tuple returned by the helper function.
        // It fixes the issue where `getNextPrayer` was called and the variable was not found.
        guard let (nextPrayer, nextPrayerDate) = timeLogicHelper.getNextUpcomingPrayer(from: prayersForNextPrayer, after: Date()) else {
            self.nextPrayerName = ""
            self.timeUntilNextPrayer = ""
            return
        }
            
        let timeInterval = nextPrayerDate.timeIntervalSince(Date())
        self.nextPrayerName = String(format: NSLocalizedString("Next Prayer: %@", comment: ""), NSLocalizedString(nextPrayer.name, comment: ""))
        self.timeUntilNextPrayer = timeLogicHelper.format(timeInterval: timeInterval)
    }
    
    private func updatePrayerWindowStatus() {
        let updatedPrayers = prayers.map { prayer in
            var newPrayer = prayer
            
            // Check if the prayer's window has ended and it hasn't been completed
            // FIX: Corrected method name from `getPrayerWindowEnd` to `hasPrayerWindowEnded`.
            if newPrayer.status == .upcoming && timeLogicHelper.hasPrayerWindowEnded(for: newPrayer, allPrayers: self.prayers) {
                newPrayer.status = .missed
            }
            return newPrayer
        }
        
        if updatedPrayers != prayers {
            prayers = updatedPrayers
        }
    }

    // MARK: - Prayer Status Management

    func togglePrayerStatus(for prayer: Prayer, to newStatus: PrayerStatus) {
        guard let index = prayers.firstIndex(where: { $0.id == prayer.id }) else { return }
        
        if prayers[index].status != newStatus {
            prayers[index].status = newStatus
            PrayerNotificationScheduler.shared.removePendingNotifications(for: prayer)
            handleReminderRepeats()
            
            // Re-schedule main notifications for other upcoming prayers if one is marked as completed
            if newStatus == .completed {
                let remainingPrayers = prayers.filter { $0.status == .upcoming }
                PrayerNotificationScheduler.shared.scheduleNotifications(for: remainingPrayers)
            }
        }
    }
    
    // MARK: - View Helper Functions

    func statusIcon(for prayer: Prayer) -> String {
        switch prayer.status {
        case .completed:
            return "checkmark.circle.fill"
        case .missed:
            return "xmark.circle.fill"
        case .upcoming:
            // FIX: Removed the extra `allPrayers` argument to match the helper function.
            return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers) ? "bell.fill" : "circle.dashed"
        }
    }
    
    func statusColor(for prayer: Prayer) -> Color {
        switch prayer.status {
        case .completed:
            return .green
        case .missed:
            return .red
        case .upcoming:
            // FIX: Removed the extra `allPrayers` argument to match the helper function.
            return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers) ? .blue : .secondary
        }
    }
    
    func statusLabel(for prayer: Prayer) -> String {
        switch prayer.status {
        case .completed:
            return NSLocalizedString("Prayed", comment: "")
        case .missed:
            return NSLocalizedString("Missed", comment: "")
        case .upcoming:
            // FIX: Removed the extra `allPrayers` argument to match the helper function.
            return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers) ? NSLocalizedString("Active", comment: "") : NSLocalizedString("Upcoming", comment: "")
        }
    }
    
    func isPrayerCurrentlyActive(for prayer: Prayer) -> Bool {
        // FIX: Removed the extra `allPrayers` argument to match the helper function.
        return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers)
    }

    func hasPrayerTimePassed(for prayer: Prayer) -> Bool {
        return timeLogicHelper.hasPrayerTimePassed(for: prayer)
    }

    func hasPrayerWindowEnded(for prayer: Prayer) -> Bool {
        // FIX: Corrected method name from `getPrayerWindowEnd` to `hasPrayerWindowEnded`.
        return timeLogicHelper.hasPrayerWindowEnded(for: prayer, allPrayers: prayers)
    }
    
    // MARK: - Reminders & Notifications
    
    func handleReminderRepeats() {
        guard reminderEnabled else {
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
            return
        }
        
        if let activePrayer = currentActivePrayer, activePrayer.status == .upcoming {
            PrayerReminderRepeater.shared.startRepeatingReminder(for: activePrayer, every: userReminderIntervalInMinutes, shouldRemind: reminderEnabled)
        } else {
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let userInfo = response.notification.request.content.userInfo as? [String: Any],
              let prayerName = userInfo["prayerName"] as? String else {
            completionHandler()
            return
        }
        
        Task { @MainActor in
            switch response.actionIdentifier {
            case PrayerNotificationScheduler.prayedActionIdentifier:
                if let prayerToUpdate = self.prayers.first(where: { $0.name == prayerName }) {
                    self.togglePrayerStatus(for: prayerToUpdate, to: .completed)
                }
            default:
                break
            }
            
            completionHandler()
        }
    }
    
    // MARK: - Language Change
    
    func applyLanguageChange(_ languageCode: String) {
        isLanguageChanging = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedLanguageCode = languageCode
            self.isLanguageChanging = false
            self.refreshID = UUID()
            print("🌐 ViewModel: Language changed to \(languageCode).")
        }
    }
    
    private func updateHistoricalData(for currentPrayers: [Prayer]) {
        let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let currentDayData = SavedPrayerData(date: todayString, prayers: currentPrayers)
        
        if let index = historicalPrayerData.firstIndex(where: { $0.date == todayString }) {
            historicalPrayerData[index] = currentDayData
        } else {
            historicalPrayerData.append(currentDayData)
        }
        print("ViewModel: Historical data updated for \(todayString). Total historical days: \(historicalPrayerData.count)")
    }

    func checkIfAllPrayersCompleted(for date: Date) -> Bool {
        let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        
        guard let dayData = historicalPrayerData.first(where: { $0.date == dateString }) else {
            return false
        }
        
        let relevantPrayers = dayData.prayers.filter { $0.name != "Sunrise" }
        return !relevantPrayers.isEmpty && relevantPrayers.allSatisfy { $0.status == .completed }
    }
    
    // MARK: - Helper for PrayerCalendarView
    
    private var historicalPrayerData: [SavedPrayerData] {
        get {
            return dataStore.loadAllSavedPrayerData() ?? []
        }
        set {
            dataStore.saveAllPrayerData(newValue)
        }
    }

    func prayerStatus(for date: Date) -> PrayerStatus? {
        let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        
        guard let dayData = historicalPrayerData.first(where: { $0.date == dateString }) else {
            return nil
        }
        
        let relevantPrayers = dayData.prayers.filter { $0.name != "Sunrise" }
        
        if relevantPrayers.allSatisfy({ $0.status == .completed }) {
            return .completed
        } else if relevantPrayers.allSatisfy({ $0.status == .missed }) {
            return .missed
        } else {
            return .upcoming
        }
    }
}
