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
    // MARK: - AppStorage Properties
    @AppStorage("userReminderIntervalInMinutes") private var userReminderIntervalInMinutes: Int = 10
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = true
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode: String = "en"
    // REMOVED: The manual calculation method is no longer needed.
    // @AppStorage("selectedCalculationMethod") private var selectedCalculationMethod: Int = 12
    @AppStorage("lastFetchedDate") private var lastFetchedDate: String = ""

    // MARK: - Published Properties for UI
    @Published var isLoading = true
    @Published var loadingFailed = false
    @Published var isLanguageChanging = false
    @Published var refreshID = UUID()
    @Published var prayers: [Prayer] = []
    @Published var historicalPrayerData: [SavedPrayerData] = []

    @Published var lastFetchedLatitude: CLLocationDegrees?
    @Published var lastFetchedLongitude: CLLocationDegrees?
    
    @Published var isDay: Bool = true {
        didSet {
            print("🌓 ViewModel: isDay didSet: \(isDay ? "Day" : "Night")")
        }
    }
    
    @Published var nextPrayerName: String = ""
    @Published var timeUntilNextPrayer: String = ""

    // MARK: - Private Properties
    private let dataStore = CloudKitDataStore()
    private let timeLogicHelper = PrayerTimeLogicHelper()
    private let locationManager = CLLocationManager()
    private let apiService = AladhanAPIService()
    
    private var cancellables = Set<AnyCancellable>()
    private var isSaving = false

    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationDelegate()
        setupLocationManager()
        
        startTimer()
        
        $prayers
            .dropFirst()
            .sink { [weak self] newPrayers in
                self?.handlePrayersUpdate(newPrayers)
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
        PrayerNotificationScheduler.shared.registerNotificationCategory()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Data Loading and Handling
    
    func loadInitialData() {
        Task {
            isLoading = true
            loadingFailed = false

            await loadHistoricalData()
            
            let todayKey = DateFormatter.databaseKeyFormatter.string(from: Date())
            
            if let todayData = historicalPrayerData.first(where: { $0.date == todayKey }) {
                self.prayers = todayData.prayers
                self.isLoading = false
                print("✅ ViewModel: Loaded today's prayers from CloudKit cache for key: \(todayKey).")
            } else {
                print("ℹ️ ViewModel: No data for today in CloudKit for key: \(todayKey). Requesting location...")
                requestLocation()
            }
        }
    }
    
    private func handlePrayersUpdate(_ updatedPrayers: [Prayer]) {
        savePrayersToCloudKit(updatedPrayers)
        isDay = timeLogicHelper.isDaytime(prayers: updatedPrayers)
    }

    private func savePrayersToCloudKit(_ prayersToSave: [Prayer]) {
        guard !isSaving else {
            print("☁️ CloudKit: Save operation already in progress. Skipping.")
            return
        }
        guard !prayersToSave.isEmpty else { return }
        
        let todayKey = DateFormatter.databaseKeyFormatter.string(from: Date())
        let currentDayData = SavedPrayerData(date: todayKey, prayers: prayersToSave)
        
        isSaving = true
        
        Task {
            defer { self.isSaving = false }
            
            do {
                try await dataStore.save(currentDayData)
                if let index = self.historicalPrayerData.firstIndex(where: { $0.id == currentDayData.id }) {
                    self.historicalPrayerData[index] = currentDayData
                } else {
                    self.historicalPrayerData.insert(currentDayData, at: 0)
                }
            } catch {
                print("❌ ViewModel: Failed to save prayers to CloudKit: \(error.localizedDescription)")
            }
        }
    }

    private func loadHistoricalData() async {
        do {
            self.historicalPrayerData = try await dataStore.fetchAllPrayerData()
        } catch {
            print("❌ ViewModel: Failed to load historical data from CloudKit: \(error.localizedDescription)")
            self.loadingFailed = true
            self.isLoading = false
        }
    }

    // MARK: - Location Management
    func requestLocation() {
        print("📍 ViewModel: Requesting location authorization.")
        locationManager.requestWhenInUseAuthorization()
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ ViewModel: Location authorization granted. Starting to update location.")
                manager.startUpdatingLocation()
            case .denied, .restricted:
                print("❌ ViewModel: Location access denied or restricted. Using fallback location.")
                await self.fetchPrayerTimes(latitude: 41.0082, longitude: 28.9784)
            case .notDetermined:
                print("⏳ ViewModel: Location authorization not determined.")
            @unknown default:
                print("⚠️ ViewModel: Unknown authorization status.")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else { return }
            manager.stopUpdatingLocation()
            
            self.lastFetchedLatitude = location.coordinate.latitude
            self.lastFetchedLongitude = location.coordinate.longitude
            
            print("📍 ViewModel: New location received. Latitude: \(location.coordinate.latitude), Longitude: \(location.coordinate.longitude)")
            
            let todayKey = DateFormatter.databaseKeyFormatter.string(from: Date())
            if lastFetchedDate != todayKey || self.prayers.isEmpty {
                await self.fetchPrayerTimes(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            } else {
                self.isLoading = false
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ ViewModel: Failed to get user location: \(error.localizedDescription)")
            await self.fetchPrayerTimes(latitude: 41.0082, longitude: 28.9784)
        }
    }

    // MARK: - API & Data Fetching
    func fetchPrayerTimes(latitude: Double, longitude: Double) async {
        // CORRECTED: Log message no longer includes a method.
        print("🌐 ViewModel: Fetching prayer times for \(latitude), \(longitude) using automatic method detection...")
        self.isLoading = true
        self.loadingFailed = false
        
        do {
            // CORRECTED: The call to the API service no longer passes a manual method.
            let fetchedPrayers = try await apiService.fetchPrayerTimes(
                latitude: latitude,
                longitude: longitude,
                using: self.timeLogicHelper
            )
            
            let mergedPrayers = self.merge(newPrayers: fetchedPrayers, with: self.prayers)
            self.prayers = mergedPrayers
            
            self.lastFetchedDate = DateFormatter.databaseKeyFormatter.string(from: Date())
            self.isLoading = false
            
            self.scheduleAllReminders(for: mergedPrayers)
            
            print("✅ ViewModel: Successfully fetched prayer times.")
        } catch {
            print("❌ ViewModel: Failed to fetch prayer times: \(error.localizedDescription)")
            self.isLoading = false
            self.loadingFailed = true
        }
    }
    
    private func merge(newPrayers: [Prayer], with existingPrayers: [Prayer]) -> [Prayer] {
        guard !existingPrayers.isEmpty else { return newPrayers }
        
        return newPrayers.map { newPrayer in
            if let existingPrayer = existingPrayers.first(where: { $0.id == newPrayer.id }) {
                if existingPrayer.status == .completed {
                    var finalPrayer = newPrayer
                    finalPrayer.status = .completed
                    return finalPrayer
                }
            }
            return newPrayer
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
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimeUntilNextPrayer()
                self?.updatePrayerWindowStatus()
            }
            .store(in: &cancellables)
    }

    private func updateTimeUntilNextPrayer() {
        guard let (nextPrayer, nextPrayerDate) = timeLogicHelper.getNextUpcomingPrayer(from: self.prayers, after: Date()) else {
            self.nextPrayerName = NSLocalizedString("All prayers done for today!", comment: "Message when all prayers are completed")
            self.timeUntilNextPrayer = "🎉"
            return
        }
        let timeInterval = nextPrayerDate.timeIntervalSince(Date())
        self.nextPrayerName = String(format: NSLocalizedString("Next Prayer: %@", comment: ""), NSLocalizedString(nextPrayer.name, comment: ""))
        self.timeUntilNextPrayer = timeLogicHelper.format(timeInterval: timeInterval)
    }
    
    private func updatePrayerWindowStatus() {
        var didChange = false
        var updatedPrayers = self.prayers
        
        for (index, prayer) in updatedPrayers.enumerated() {
            if prayer.status == .upcoming && timeLogicHelper.hasPrayerWindowEnded(for: prayer, allPrayers: self.prayers) {
                updatedPrayers[index].status = .missed
                didChange = true
            }
        }
        
        if didChange {
            self.prayers = updatedPrayers
        }
    }

    // MARK: - Prayer Status Management
    var currentActivePrayer: Prayer? {
        let prayersForActiveCheck = prayers.filter { $0.name != "Sunrise" }
        return prayersForActiveCheck.first { timeLogicHelper.isPrayerCurrentlyActive(for: $0, allPrayers: prayersForActiveCheck) }
    }

    func togglePrayerStatus(for prayer: Prayer, to newStatus: PrayerStatus) {
        guard let index = prayers.firstIndex(where: { $0.id == prayer.id }) else { return }
        
        if prayers[index].status != newStatus {
            prayers[index].status = newStatus
            
            PrayerReminderRepeater.shared.cancelRepeatingReminders(for: prayer)
        }
    }
    
    // MARK: - Reminders & Notifications
    
    private func scheduleAllReminders(for prayers: [Prayer]) {
        PrayerNotificationScheduler.shared.cancelAllNotifications()
        PrayerNotificationScheduler.shared.scheduleNotifications(for: prayers)
        
        if reminderEnabled {
            PrayerReminderRepeater.shared.scheduleAllFollowUpReminders(
                for: prayers,
                every: userReminderIntervalInMinutes,
                using: timeLogicHelper
            )
        }
    }
    
    func handleReminderSettingsChange() {
        scheduleAllReminders(for: self.prayers)
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let userInfo = response.notification.request.content.userInfo as? [String: Any],
              let prayerName = userInfo["prayerName"] as? String else {
            completionHandler()
            return
        }
        
        Task { @MainActor in
            if response.actionIdentifier == PrayerNotificationScheduler.prayedActionIdentifier {
                if let prayerToUpdate = self.prayers.first(where: { $0.name == prayerName }) {
                    self.togglePrayerStatus(for: prayerToUpdate, to: .completed)
                }
            }
            completionHandler()
        }
    }
    
    // MARK: - View Helper Functions
    func statusIcon(for prayer: Prayer) -> String {
        switch prayer.status {
        case .completed: return "checkmark.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .upcoming:
            return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers) ? "bell.fill" : "circle.dashed"
        }
    }
    
    func statusColor(for prayer: Prayer) -> Color {
        switch prayer.status {
        case .completed: return .green
        case .missed: return .red
        case .upcoming:
            return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers) ? .blue : .secondary
        }
    }
    
    func statusLabel(for prayer: Prayer) -> String {
        switch prayer.status {
        case .completed: return NSLocalizedString("Prayed", comment: "")
        case .missed: return NSLocalizedString("Missed", comment: "")
        case .upcoming:
            return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers) ? NSLocalizedString("Active", comment: "") : NSLocalizedString("Upcoming", comment: "")
        }
    }
    
    func isPrayerCurrentlyActive(for prayer: Prayer) -> Bool {
        return timeLogicHelper.isPrayerCurrentlyActive(for: prayer, allPrayers: prayers)
    }

    func hasPrayerTimePassed(for prayer: Prayer) -> Bool {
        return timeLogicHelper.hasPrayerTimePassed(for: prayer)
    }

    func hasPrayerWindowEnded(for prayer: Prayer) -> Bool {
        return timeLogicHelper.hasPrayerWindowEnded(for: prayer, allPrayers: prayers)
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
    
    // MARK: - Calendar View Helper
    func checkIfAllPrayersCompleted(for date: Date) -> Bool {
        let dateKey = DateFormatter.databaseKeyFormatter.string(from: date)
        guard let dayData = historicalPrayerData.first(where: { $0.date == dateKey }) else {
            return false
        }
        let relevantPrayers = dayData.prayers.filter { $0.name != "Sunrise" }
        return !relevantPrayers.isEmpty && relevantPrayers.allSatisfy { $0.status == .completed }
    }
}
