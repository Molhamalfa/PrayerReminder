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
class PrayerReminderViewModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate, Identifiable {
    // MARK: - AppStorage Properties
    @AppStorage("userReminderIntervalInMinutes") private var userReminderIntervalInMinutes: Int = 10
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = true
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode: String = "en"
    @AppStorage("lastFetchedDate") private var lastFetchedDate: String = ""

    // MARK: - Published Properties for UI
    @Published var isLoading = true
    @Published var loadingFailed = false
    @Published var errorMessage: String? = nil
    @Published var isLanguageChanging = false
    @Published var refreshID = UUID()
    @Published var prayers: [Prayer] = []
    @Published var historicalPrayerData: [SavedPrayerData] = []
    @Published var lastFetchedLatitude: CLLocationDegrees?
    @Published var lastFetchedLongitude: CLLocationDegrees?
    @Published var isDay: Bool = true
    @Published var nextPrayerName: String = ""
    @Published var timeUntilNextPrayer: String = ""

    // MARK: - Private Properties
    private let dataStore = CloudKitDataStore()
    private let timeLogicHelper = PrayerTimeLogicHelper()
    private let locationService = LocationService()
    private let apiService = AladhanAPIService()
    private var cancellables = Set<AnyCancellable>()
    private var isSaving = false

    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationDelegate()
        setupLocationSubscriber()
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
    
    private func setupLocationSubscriber() {
        locationService.locationPublisher
            .sink { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let location):
                    self.handleLocationUpdate(location)
                case .failure(let error):
                    self.handleLocationFailure(error)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading and Handling
    func loadInitialData() {
        Task {
            isLoading = true
            loadingFailed = false
            errorMessage = nil

            await loadHistoricalData()
            
            let todayKey = DateFormatter.databaseKeyFormatter.string(from: Date())
            
            if let todayData = historicalPrayerData.first(where: { $0.date == todayKey }) {
                self.prayers = todayData.prayers
                self.isLoading = false
                print("✅ ViewModel: Loaded today's prayers from CloudKit cache.")
            } else {
                print("ℹ️ ViewModel: No data for today in cache. Requesting location...")
                locationService.requestLocationAuthorization()
            }
        }
    }
    
    private func handlePrayersUpdate(_ updatedPrayers: [Prayer]) {
        savePrayersToCloudKit(updatedPrayers)
        isDay = timeLogicHelper.isDaytime(prayers: updatedPrayers)
    }

    private func savePrayersToCloudKit(_ prayersToSave: [Prayer]) {
        guard !isSaving, !prayersToSave.isEmpty else { return }
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
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    // MARK: - Location Management
    private func handleLocationUpdate(_ location: CLLocation) {
        lastFetchedLatitude = location.coordinate.latitude
        lastFetchedLongitude = location.coordinate.longitude
        print("📍 ViewModel: New location received from service.")
        
        let todayKey = DateFormatter.databaseKeyFormatter.string(from: Date())
        if lastFetchedDate != todayKey || self.prayers.isEmpty {
            Task {
                await fetchPrayerTimes(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        } else {
            isLoading = false
        }
    }

    private func handleLocationFailure(_ error: Error) {
        print("❌ ViewModel: Location failure from service. Using fallback.")
        Task {
            await fetchPrayerTimes(latitude: 41.0082, longitude: 28.9784)
        }
    }

    // MARK: - API & Data Fetching
    func fetchPrayerTimes(latitude: Double, longitude: Double) async {
        print("🌐 ViewModel: Fetching prayer times...")
        isLoading = true
        loadingFailed = false
        errorMessage = nil
        
        do {
            let fetchedPrayers = try await apiService.fetchPrayerTimes(latitude: latitude, longitude: longitude, using: self.timeLogicHelper)
            let mergedPrayers = self.merge(newPrayers: fetchedPrayers, with: self.prayers)
            self.prayers = mergedPrayers
            
            // This is the crucial step to update the date after a successful fetch.
            self.lastFetchedDate = DateFormatter.databaseKeyFormatter.string(from: Date())
            
            isLoading = false
            scheduleAllReminders(for: mergedPrayers)
            print("✅ ViewModel: Successfully fetched prayer times.")
        } catch {
            print("❌ ViewModel: Failed to fetch prayer times: \(error.localizedDescription)")
            isLoading = false
            loadingFailed = true
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    private func merge(newPrayers: [Prayer], with existingPrayers: [Prayer]) -> [Prayer] {
        guard !existingPrayers.isEmpty else { return newPrayers }
        return newPrayers.map { newPrayer in
            if let existingPrayer = existingPrayers.first(where: { $0.id == newPrayer.id }), existingPrayer.status == .completed {
                var finalPrayer = newPrayer
                finalPrayer.status = .completed
                return finalPrayer
            }
            return newPrayer
        }
    }

    func refreshPrayerTimes() async {
        guard let lat = lastFetchedLatitude, let lon = lastFetchedLongitude else {
            locationService.requestLocationAuthorization()
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
                // NEW: Check if the day has changed on every timer tick.
                self?.checkForNewDay()
            }
            .store(in: &cancellables)
    }
    
    // NEW: This function checks if the date has changed and triggers a refresh.
    private func checkForNewDay() {
        let todayKey = DateFormatter.databaseKeyFormatter.string(from: Date())
        if todayKey != lastFetchedDate {
            print("🌅 ViewModel: New day detected! Refreshing prayer times.")
            // Calling loadInitialData will trigger the entire refresh flow,
            // including fetching new times and rescheduling all notifications.
            loadInitialData()
        }
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
            
            if newStatus == .completed {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                PrayerReminderRepeater.shared.cancelRepeatingReminders(for: prayer)
            }
        }
    }
    
    // MARK: - Reminders & Notifications
    private func scheduleAllReminders(for prayers: [Prayer]) {
        PrayerNotificationScheduler.shared.cancelAllNotifications()
        PrayerNotificationScheduler.shared.scheduleNotifications(for: prayers)
        
        if reminderEnabled {
            PrayerReminderRepeater.shared.scheduleAllFollowUpReminders(for: prayers, every: userReminderIntervalInMinutes, using: timeLogicHelper)
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
