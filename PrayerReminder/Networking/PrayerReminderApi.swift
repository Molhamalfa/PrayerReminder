//
//  PrayerReminderApi.swift
//  PrayerReminder
//
//  Created by Mac on 24.07.2025.
//


// MARK: - API Handler

import Foundation
import Combine
import CoreLocation

class PrayerReminderApi {
    // Reverted to Aladhan API base URL
    static func fetchPrayerTimes(for coordinate: CLLocationCoordinate2D, method: Int) -> AnyPublisher<PrayerTimesResponse, Error> {
        // Aladhan API endpoint: https://api.aladhan.com/v1/timings?latitude=LATITUDE&longitude=LONGITUDE&method=METHOD_ID
        let urlString = "https://api.aladhan.com/v1/timings?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&method=\(method)"
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        print("Fetching prayer times from: \(url.absoluteString)")

        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("API HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("API Response Body: \(responseString)")
                    }
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: PrayerTimesResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
        
    }
}
