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
            updateActivePrayerAndTimer()
            PrayerNotificationScheduler.shared.scheduleNotifications(for: prayers)
            updateHistoricalData(for: prayers)
        }
    }
    
    @Published var historicalPrayerData: [SavedPrayerData] = []
    
    // MARK: - Prayer Time and Logic
    @Published private(set) var currentActivePrayer: Prayer?
    @Published private(set) var nextPrayerName: String = ""
    @Published private(set) var timeUntilNextPrayer: String = ""
    private var prayerTimer: AnyCancellable?
    private var fetchCancellable: AnyCancellable?
    
    // MARK: - Initializer & Setup
    override init() {
        super.init()
        setupLocationManager()
        setupNotificationCenter()
        loadHistoricalData()
        PrayerNotificationScheduler.shared.registerNotificationCategory()
        
        // Timer to update the countdown every minute
        prayerTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateActivePrayerAndTimer()
                self.updateIsDayState()
                
                // Fetch new prayer times at Fajr to get tomorrow's times if needed
                if self.isFajrTime(Date()) {
                    print("⏰ It's Fajr time. Refreshing prayer times for the new day.")
                    Task { await self.loadPrayerTimes() }
                }
            }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func loadHistoricalData() {
        if let savedData = dataStore.loadAllSavedPrayerData() {
            self.historicalPrayerData = savedData
            print("✅ ViewModel: Loaded \(self.historicalPrayerData.count) days of historical data.")
        }
    }
    
    private func updateActivePrayerAndTimer() {
        let now = Date()
        guard !prayers.isEmpty else {
            print("⚠️ ViewModel: No active prayer found. Stopping repeating reminders.")
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
            return
        }

        if let (nextPrayer, nextPrayerDate) = timeLogicHelper.findNextPrayer(from: prayers, now: now) {
            currentActivePrayer = timeLogicHelper.isPrayerCurrentlyActive(nextPrayer, allPrayers: prayers) ? nextPrayer : nil
            nextPrayerName = String(format: NSLocalizedString("Time until %@", comment: "Time until next prayer"), NSLocalizedString(nextPrayer.name, comment: ""))
            
            let timeInterval = nextPrayerDate.timeIntervalSince(now)
            timeUntilNextPrayer = timeLogicHelper.format(timeInterval: timeInterval)
            
            // Manage repeating reminders
            if let activePrayer = currentActivePrayer, activePrayer.status == .upcoming {
                let reminderInterval = userReminderIntervalInMinutes
                let shouldRemind = reminderEnabled && (activePrayer.status == .upcoming)
                PrayerReminderRepeater.shared.startRepeatingReminder(for: activePrayer, every: reminderInterval, shouldRemind: shouldRemind)
            } else {
                PrayerReminderRepeater.shared.stopAllRepeatingReminders()
            }
        } else {
            nextPrayerName = NSLocalizedString("Waiting for Fajr", comment: "")
            timeUntilNextPrayer = "--h --m"
        }
    }
    
    // Check if it is Fajr time
    private func isFajrTime(_ date: Date) -> Bool {
        guard let fajrPrayer = prayers.first(where: { $0.name == "Fajr" }) else { return false }
        guard let fajrTime = timeLogicHelper.date(for: fajrPrayer.time, basedOn: date) else { return false }
        
        let nowComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
        let fajrComponents = Calendar.current.dateComponents([.hour, .minute], from: fajrTime)
        
        return nowComponents.hour == fajrComponents.hour && nowComponents.minute == fajrComponents.minute
    }
    
    // Update isDay based on Fajr and Maghrib times
    private func updateIsDayState() {
        self.isDay = timeLogicHelper.isDaytime(prayers: prayers)
    }

    // MARK: - API & Location Management
    func requestLocation() {
        print("🌍 ViewModel: Requesting location authorization status...")
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            print("🌍 ViewModel: Location authorization granted. Requesting location.")
            locationManager.requestLocation()
        case .denied, .restricted:
            loadingFailed = true
            print("❌ ViewModel: Location authorization denied or restricted.")
        @unknown default:
            loadingFailed = true
            print("❌ ViewModel: Unknown location authorization status.")
        }
    }

    // FIX: Made loadPrayerTimes an async function
    func loadPrayerTimes() async {
        isLoading = true
        
        defer {
            isLoading = false
        }

        guard let latitude = lastFetchedLatitude, let longitude = lastFetchedLongitude else {
            print("⚠️ ViewModel: No last fetched location, cannot load prayer times.")
            return
        }

        let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let savedPrayers = dataStore.loadSavedPrayersForToday(),
           lastFetchedDate == todayString {
            print("✅ ViewModel: Location and date are the same. Loading saved prayers.")
            self.prayers = savedPrayers.prayers
            return
        }
        
        do {
            print("🌍 ViewModel: Fetching prayer times for lat: \(latitude), lon: \(longitude), method: \(selectedCalculationMethod)")
            let fetchedPrayers = try await apiService.fetchPrayerTimes(latitude: latitude, longitude: longitude, method: selectedCalculationMethod)
            
            let prayersWithUpcomingStatus = fetchedPrayers.map { prayer in
                var newPrayer = prayer
                newPrayer.status = .upcoming
                return newPrayer
            }
            
            self.prayers = prayersWithUpcomingStatus
            self.lastFetchedDate = todayString
            print("✅ ViewModel: Prayer times fetched successfully. Count: \(self.prayers.count)")
            
        } catch {
            print("❌ ViewModel: Failed to fetch prayer times: \(error.localizedDescription)")
            loadingFailed = true
        }
    }
    
    func refreshPrayerTimes() async {
        print("🔄 ViewModel: Manual refresh requested.")
        isLoading = true
        defer { isLoading = false }
        
        await loadPrayerTimes()
    }
    
    // MARK: - CLLocationManagerDelegate
    // FIX: Add 'nonisolated' to fix Swift 6 concurrency error.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("🌍 LocationManagerDelegateHelper: Authorization status changed to \(manager.authorizationStatus.rawValue).")
        // FIX: Wrap main actor-isolated work in a Task
        Task { @MainActor in
            requestLocation()
        }
    }
    
    // FIX: Add 'nonisolated' to fix Swift 6 concurrency error.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        print("🌍 LocationManagerDelegateHelper: Location updated.")

        // FIX: Wrap main actor-isolated work in a Task
        Task { @MainActor in
            if location.coordinate.latitude != lastFetchedLatitude || location.coordinate.longitude != lastFetchedLongitude {
                print("🌍 ViewModel: Location updated. Latitude: \(location.coordinate.latitude), Longitude: \(location.coordinate.longitude)")
                self.lastFetchedLatitude = location.coordinate.latitude
                self.lastFetchedLongitude = location.coordinate.longitude
                await self.loadPrayerTimes()
            } else {
                print("🌍 ViewModel: Location is the same. No need to fetch.")
            }
        }
    }

    // FIX: Add 'nonisolated' to fix Swift 6 concurrency error.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManagerDelegateHelper: Failed to get location: \(error.localizedDescription)")
        // FIX: Wrap main actor-isolated work in a Task
        Task { @MainActor in
            loadingFailed = true
            isLoading = false
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    // FIX: Add 'nonisolated' to fix Swift 6 concurrency error.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    // FIX: Add 'nonisolated' to fix Swift 6 concurrency error.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - UI Logic
    func statusIcon(for prayer: Prayer) -> String {
        switch prayer.status {
        case .completed:
            return "checkmark.circle.fill"
        case .missed:
            return "xmark.circle.fill"
        case .upcoming:
            if timeLogicHelper.isPrayerCurrentlyActive(prayer, allPrayers: prayers) {
                return "hourglass.tophalf.filled"
            }
            return "clock.fill"
        }
    }

    func statusColor(for prayer: Prayer) -> Color {
        switch prayer.status {
        case .completed:
            return .green
        case .missed:
            return .red
        case .upcoming:
            return .blue
        }
    }
    
    func statusLabel(for prayer: Prayer) -> String {
        switch prayer.status {
        case .upcoming:
            if timeLogicHelper.isPrayerCurrentlyActive(prayer, allPrayers: prayers) {
                return NSLocalizedString("Active", comment: "Label for currently active prayer")
            }
            return NSLocalizedString("Upcoming", comment: "Label for upcoming prayer")
        case .completed:
            return NSLocalizedString("Prayed", comment: "Label for completed prayer")
        case .missed:
            return NSLocalizedString("Missed", comment: "Label for missed prayer")
        }
    }
    
    func togglePrayerStatus(for prayer: Prayer, to newStatus: PrayerStatus) {
        guard let index = prayers.firstIndex(where: { $0.id == prayer.id }) else { return }
        
        prayers[index].status = newStatus
        print("✅ ViewModel: Status of prayer '\(prayer.name)' changed to '\(newStatus)'.")
    }
    
    func handleReminderRepeats() {
        guard let currentActive = currentActivePrayer else {
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
            return
        }
        
        if reminderEnabled && currentActive.status == .upcoming {
            PrayerReminderRepeater.shared.startRepeatingReminder(for: currentActive, every: userReminderIntervalInMinutes, shouldRemind: true)
        } else {
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
        }
    }
    
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
}
