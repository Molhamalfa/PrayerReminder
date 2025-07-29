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
            dataStore.savePrayers(prayers) // Save current day's data to history
            updateNextPrayer()
            updateHistoricalData(for: prayers) // Ensure historical data is updated
        }
    }
    
    @Published var historicalPrayerData: [SavedPrayerData] = []

    @Published var currentActivePrayer: Prayer?
    @Published var nextPrayerName: String = NSLocalizedString("Loading...", comment: "")
    @Published var timeUntilNextPrayer: String = ""

    private var timer: AnyCancellable?
    
    override init() {
        super.init()
        locationManager.delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)

        self.historicalPrayerData = dataStore.loadAllSavedPrayerData() ?? []
        print("ViewModel: Loaded \(self.historicalPrayerData.count) days of historical data.")

        if self.lastFetchedDate != todayString {
            print("ViewModel: New day detected or no lastFetchedDate. Forcing fresh fetch.")
            self.prayers = [] // Clear current day's prayers
            Task { await fetchPrayerTimes() }
        } else if let savedData = dataStore.loadPrayers() {
            self.prayers = savedData.prayers
            print("ViewModel: Loaded prayers from DataStore for today.")
            updatePrayerStatuses()
            handleReminderRepeats()
            // FIX: Explicitly schedule notifications when loading saved data for today
            PrayerNotificationScheduler.shared.scheduleNotifications(for: prayers)
        } else {
            print("ViewModel: No saved prayers for today. Fetching new times.")
            Task { await fetchPrayerTimes() }
        }
        setupTimer()
    }

    func requestLocation() {
        if !isLoading {
            isLoading = true
            loadingFailed = false
        }
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else {
                if self.isLoading {
                    self.isLoading = false
                    self.loadingFailed = true
                }
                return
            }
            manager.stopUpdatingLocation()
            
            let currentLocation = location.coordinate
            let savedLocation = (lastFetchedLatitude, lastFetchedLongitude)
            
            let locationChanged = abs(currentLocation.latitude - (savedLocation.0 ?? 0)) > 0.001 ||
                                  abs(currentLocation.longitude - (savedLocation.1 ?? 0)) > 0.001
            
            let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)

            if (!self.isLoading && (self.prayers.isEmpty || self.lastFetchedDate != todayString || locationChanged)) {
                await self.fetchPrayerTimes(for: currentLocation)
            } else if self.isLoading {
                self.isLoading = false
            } else {
                self.isLoading = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ LocationManager: Failed with error: \(error.localizedDescription)")
            self.loadingFailed = true
            self.isLoading = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
                self.loadingFailed = false
                let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                if self.prayers.isEmpty || self.lastFetchedDate != todayString && !self.isLoading {
                    self.requestLocation()
                }
            case .denied, .restricted:
                self.isLoading = false
                self.loadingFailed = true
            case .notDetermined:
                self.isLoading = false
            @unknown default:
                self.isLoading = false
            }
        }
    }

    func fetchPrayerTimes(for coordinate: CLLocationCoordinate2D? = nil) async {
        isLoading = true
        loadingFailed = false

        let lat: Double
        let lon: Double
        
        if let coordinate = coordinate {
            lat = coordinate.latitude
            lon = coordinate.longitude
        } else {
            lat = 41.0082 // Istanbul latitude
            lon = 28.9784 // Istanbul longitude
            print("Using default Istanbul coordinates for prayer times.")
        }
        
        do {
            let fetchedPrayers = try await apiService.fetchPrayerTimes(
                latitude: lat,
                longitude: lon,
                method: selectedCalculationMethod
            )
            
            let todayString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            let loadedSavedData = dataStore.loadPrayers()

            var finalPrayers = fetchedPrayers
            if let loaded = loadedSavedData, loaded.date == todayString {
                finalPrayers = fetchedPrayers.map { newPrayer in
                    if let savedPrayer = loaded.prayers.first(where: { $0.name == newPrayer.name }) {
                        if newPrayer.time == savedPrayer.time {
                            return Prayer(name: newPrayer.name, time: newPrayer.time, status: savedPrayer.status)
                        }
                    }
                    return newPrayer
                }
            }
            
            self.prayers = finalPrayers
            updatePrayerStatuses()
            handleReminderRepeats()
            PrayerNotificationScheduler.shared.scheduleNotifications(for: prayers)

            self.lastFetchedLatitude = lat
            self.lastFetchedLongitude = lon
            self.lastFetchedDate = todayString

            isLoading = false
            loadingFailed = false

        } catch {
            print("Failed to fetch prayer times: \(error)")
            isLoading = false
            loadingFailed = true
        }
    }
    
    func refreshPrayerTimes() async {
        await fetchPrayerTimes()
    }

    private func updatePrayerStatuses() {
        var updatedPrayers = prayers
        _ = Date()
        var currentActive: Prayer? = nil

        for i in 0..<updatedPrayers.count {
            let prayer = updatedPrayers[i]
            
            if prayer.name == "Sunrise" {
                if timeLogicHelper.hasPrayerTimePassed(for: prayer) {
                    updatedPrayers[i].status = .completed
                } else {
                    updatedPrayers[i].status = .upcoming
                }
                continue
            }

            let hasPassed = timeLogicHelper.hasPrayerTimePassed(for: prayer)
            let windowEnded = timeLogicHelper.hasPrayerWindowEnded(for: prayer, allPrayers: prayers)

            if prayer.status == .completed {
                continue
            } else if windowEnded {
                updatedPrayers[i].status = .missed
            } else if hasPassed {
                updatedPrayers[i].status = .upcoming
                if currentActive == nil {
                    currentActive = updatedPrayers[i]
                }
            } else {
                updatedPrayers[i].status = .upcoming
            }
        }
        
        if updatedPrayers != prayers {
            self.prayers = updatedPrayers
        }

        self.currentActivePrayer = currentActive
        handleReminderRepeats()
        updateDayNightStatus()
    }
    
    func togglePrayerStatus(for prayer: Prayer, to newStatus: PrayerStatus) {
        guard prayer.name != "Sunrise" else {
            print("⚠️ ViewModel: Cannot manually toggle Sunrise status.")
            return
        }

        if let index = prayers.firstIndex(where: { $0.id == prayer.id }) {
            var updatedPrayers = prayers
            if (prayer.status == .upcoming && newStatus == .completed) ||
               (prayer.status == .missed && newStatus == .completed) {
                updatedPrayers[index].status = newStatus
                self.prayers = updatedPrayers
                
                if currentActivePrayer?.id == prayer.id {
                    currentActivePrayer = nil
                }
                
                PrayerNotificationScheduler.shared.cancelSpecificNotification(forPrayerNamed: prayer.name)
                PrayerReminderRepeater.shared.stopAllRepeatingReminders()
                
                updateNextPrayer()
                handleReminderRepeats()
            } else {
                print("⚠️ ViewModel: Invalid status transition attempt for \(prayer.name): from \(prayer.status.rawValue) to \(newStatus.rawValue)")
            }
        }
    }

    private func updateNextPrayer() {
        let now = Date()
        guard let (nextPrayer, nextPrayerDate) = timeLogicHelper.findNextPrayerAndTime(allPrayers: prayers) else {
            nextPrayerName = NSLocalizedString("All prayers completed for today.", comment: "")
            timeUntilNextPrayer = ""
            return
        }

        let localizedNextPrayerName = NSLocalizedString(nextPrayer.name, comment: "")

        let timeInterval = nextPrayerDate.timeIntervalSince(now)
        let formattedTime = timeLogicHelper.format(timeInterval: timeInterval)

        if timeInterval > 0 {
            nextPrayerName = String(format: NSLocalizedString("Time until %@", comment: ""), localizedNextPrayerName)
            timeUntilNextPrayer = formattedTime
        } else {
            nextPrayerName = String(format: NSLocalizedString("It's time for %@", comment: ""), localizedNextPrayerName)
            timeUntilNextPrayer = ""
        }
        
        isDay = timeLogicHelper.isDaytime(prayers: prayers, currentTime: now)
    }

    private func updateDayNightStatus() {
        self.isDay = timeLogicHelper.isDaytime(prayers: prayers, currentTime: Date())
    }

    private func setupTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updatePrayerStatuses()
                self.updateNextPrayer()
            }
    }

    func applyLanguageChange(_ newLanguageCode: String) {
        UserDefaults.standard.set(newLanguageCode, forKey: "selectedLanguageCode")
        selectedLanguageCode = newLanguageCode
        
        Task {
            isLanguageChanging = true
            await fetchPrayerTimes()
            isLanguageChanging = false
        }
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let prayerName = userInfo["prayerName"] as? String else {
            completionHandler()
            return
        }
        
        Task { @MainActor in
            switch response.actionIdentifier {
            case PrayerNotificationScheduler.prayedActionIdentifier:
                if let prayerToUpdate = self.prayers.first(where: { $0.name == prayerName }) {
                    self.togglePrayerStatus(for: prayerToUpdate, to: .completed)
                }
                
            case UNNotificationDefaultActionIdentifier:
                break
                
            case UNNotificationDismissActionIdentifier:
                break
                
            default:
                break
            }
            completionHandler()
        }
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func handleReminderRepeats() {
        guard reminderEnabled else {
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
            return
        }

        let currentlyActiveAndUpcomingPrayer = prayers.first(where: {
            guard $0.name != "Sunrise" else { return false }
            
            let isActive = timeLogicHelper.isPrayerCurrentlyActive($0, allPrayers: prayers)
            let isUpcoming = $0.status == .upcoming
            return isActive && isUpcoming
        })
        
        self.currentActivePrayer = currentlyActiveAndUpcomingPrayer

        if let activePrayer = currentlyActiveAndUpcomingPrayer {
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
            PrayerReminderRepeater.shared.startRepeatingReminder(for: activePrayer, every: userReminderIntervalInMinutes, shouldRemind: true)
        } else {
            PrayerReminderRepeater.shared.stopAllRepeatingReminders()
        }
    }
    
    // MARK: - Public Helper Methods for Views
    func checkPrayerTimePassed(for prayer: Prayer) -> Bool {
        return timeLogicHelper.hasPrayerTimePassed(for: prayer)
    }

    func checkPrayerCurrentlyActive(for prayer: Prayer) -> Bool {
        guard !prayers.isEmpty else { return false }
        return timeLogicHelper.isPrayerCurrentlyActive(prayer, allPrayers: self.prayers)
    }

    func checkPrayerWindowEnded(for prayer: Prayer) -> Bool {
        guard !prayers.isEmpty else { return false }
        return timeLogicHelper.hasPrayerWindowEnded(for: prayer, allPrayers: self.prayers)
    }

    // MARK: - UI Display Logic (Closures for Views)
    func statusIcon(for prayer: Prayer) -> String {
        if prayer.name == "Sunrise" { return "sunrise.fill" }
        
        switch prayer.status {
        case .upcoming:
            if checkPrayerCurrentlyActive(for: prayer) {
                return "hourglass.tophalf.filled"
            }
            return "hourglass"
        case .completed:
            return "checkmark.circle.fill"
        case .missed:
            return "xmark.circle.fill"
        }
    }

    func statusColor(for prayer: Prayer) -> Color {
        if prayer.name == "Sunrise" { return .orange }
        
        switch prayer.status {
        case .upcoming:
            if checkPrayerCurrentlyActive(for: prayer) {
                return .blue
            }
            return .gray
        case .completed:
            return .green
        case .missed:
            return .red
        }
    }
    
    func statusLabel(for prayer: Prayer) -> String {
        if prayer.name == "Sunrise" { return NSLocalizedString("Sunrise", comment: "") }
        
        switch prayer.status {
        case .upcoming:
            if checkPrayerCurrentlyActive(for: prayer) {
                return NSLocalizedString("Active", comment: "Label for currently active prayer")
            }
            return NSLocalizedString("Upcoming", comment: "Label for upcoming prayer")
        case .completed:
            return NSLocalizedString("Prayed", comment: "Label for completed prayer")
        case .missed:
            return NSLocalizedString("Missed", comment: "Label for missed prayer")
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
