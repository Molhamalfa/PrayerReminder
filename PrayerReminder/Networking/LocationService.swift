//
//  LocationService.swift
//  PrayerReminder
//
//  Created by Mac on 18.08.2025.
//

import Foundation
import CoreLocation
import Combine

/// An enumeration representing the possible outcomes of a location request.
enum LocationResult {
    case success(CLLocation)
    case failure(Error)
}

/// A dedicated service to manage all CoreLocation interactions.
@MainActor
class LocationService: NSObject, CLLocationManagerDelegate {
    
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    
    /// A Combine publisher that emits the result of a location request.
    let locationPublisher = PassthroughSubject<LocationResult, Never>()

    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Public Methods
    
    /// Starts the process of requesting location authorization from the user.
    func requestLocationAuthorization() {
        print("📍 LocationService: Requesting location authorization.")
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    
    // Using nonisolated as the delegate method is not guaranteed to be on the main actor.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ LocationService: Authorization granted. Starting to update location.")
                manager.startUpdatingLocation()
            case .denied, .restricted:
                print("❌ LocationService: Access denied or restricted.")
                // Send a failure result so the UI can react.
                let error = NSError(domain: "LocationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location access was denied."])
                locationPublisher.send(.failure(error))
            case .notDetermined:
                print("⏳ LocationService: Authorization not determined yet.")
            @unknown default:
                print("⚠️ LocationService: Unknown authorization status.")
            }
        }
    }
    
    // Using nonisolated as the delegate method is not guaranteed to be on the main actor.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else { return }
            print("📍 LocationService: Location received: \(location.coordinate)")
            manager.stopUpdatingLocation()
            // Send the successful location result.
            locationPublisher.send(.success(location))
        }
    }
    
    // Using nonisolated as the delegate method is not guaranteed to be on the main actor.
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ LocationService: Failed to get location: \(error.localizedDescription)")
            // Send the failure result.
            locationPublisher.send(.failure(error))
        }
    }
}
