//
//  AladhanAPIService.swift
//  PrayerReminder
//
//  Created by Mac on 27.07.2025.
//

import Foundation
import CoreLocation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case apiError(code: Int, status: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("The API URL is invalid.", comment: "Error description for invalid URL")
        case .noData:
            return NSLocalizedString("No data received from the API.", comment: "Error description for no data")
        case .decodingError(let error):
            return NSLocalizedString("Failed to decode API response: \(error.localizedDescription)", comment: "Error description for decoding failure")
        case .networkError(let error):
            return NSLocalizedString("Network error: \(error.localizedDescription)", comment: "Error description for network issues")
        case .apiError(let code, let status):
            return NSLocalizedString("API Error \(code): \(status)", comment: "Error description for API-specific errors")
        }
    }
}

class AladhanAPIService {
    /// Fetches prayer times from the Aladhan API and correctly sets their initial status.
    /// - Parameters:
    ///   - latitude: The user's latitude.
    ///   - longitude: The user's longitude.
    ///   - method: The calculation method for prayer times.
    ///   - timeHelper: An instance of `PrayerTimeLogicHelper` to determine the initial status of prayers.
    /// - Returns: An array of `Prayer` objects with their correct initial status (`.upcoming` or `.missed`).
    func fetchPrayerTimes(latitude: Double, longitude: Double, method: Int, using timeHelper: PrayerTimeLogicHelper) async throws -> [Prayer] {
        let urlString = "https://api.aladhan.com/v1/timingsByAddress?address=\(latitude),\(longitude)&method=\(method)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let apiResponse = try? JSONDecoder().decode(AladhanResponse.self, from: data) {
                    throw APIError.apiError(code: apiResponse.code, status: apiResponse.status)
                } else {
                    throw APIError.networkError(NSError(domain: "HTTPError", code: statusCode, userInfo: nil))
                }
            }
            
            let apiResponse = try JSONDecoder().decode(AladhanResponse.self, from: data)

            guard let timings = apiResponse.data?.timings else {
                throw APIError.noData
            }

            // Create a temporary list of prayers, all defaulting to .upcoming.
            let initialPrayers = [
                Prayer(name: "Fajr", time: timings.Fajr, status: .upcoming),
                Prayer(name: "Sunrise", time: timings.Sunrise, status: .upcoming),
                Prayer(name: "Dhuhr", time: timings.Dhuhr, status: .upcoming),
                Prayer(name: "Asr", time: timings.Asr, status: .upcoming),
                Prayer(name: "Maghrib", time: timings.Maghrib, status: .upcoming),
                Prayer(name: "Isha", time: timings.Isha, status: .upcoming)
            ]
            
            // CORRECTED: Map over the initial list and use the time helper to set the
            // correct status for each prayer *before* returning the data.
            // This prevents the race condition and rapid UI updates.
            let prayersWithCorrectStatus = initialPrayers.map { prayer -> Prayer in
                var correctedPrayer = prayer
                // If the prayer's window has already ended today, mark it as missed from the start.
                if timeHelper.hasPrayerWindowEnded(for: prayer, allPrayers: initialPrayers) {
                    correctedPrayer.status = .missed
                }
                return correctedPrayer
            }
            
            return prayersWithCorrectStatus

        } catch let decodingError as DecodingError {
            throw APIError.decodingError(decodingError)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - API Response Model
struct AladhanResponse: Codable {
    let code: Int
    let status: String
    let data: AladhanData?
}

struct AladhanData: Codable {
    let timings: Timings
}

struct Timings: Codable {
    let Fajr: String
    let Sunrise: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
}
