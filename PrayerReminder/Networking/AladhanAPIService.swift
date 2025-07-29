//
//  AladhanAPIService.swift
//  PrayerReminder
//
//  Created by Mac on 27.07.2025.
//

import Foundation
import CoreLocation // For CLLocationCoordinate2D

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
    func fetchPrayerTimes(latitude: Double, longitude: Double, method: Int) async throws -> [Prayer] {
        let urlString = "https://api.aladhan.com/v1/timingsByAddress?address=\(latitude),\(longitude)&method=\(method)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("API Response Status Code: \(statusCode)")
                // Attempt to decode error response if available
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

            let prayers = [
                Prayer(name: "Fajr", time: timings.Fajr, status: .upcoming),
                Prayer(name: "Sunrise", time: timings.Sunrise, status: .upcoming),
                Prayer(name: "Dhuhr", time: timings.Dhuhr, status: .upcoming),
                Prayer(name: "Asr", time: timings.Asr, status: .upcoming),
                Prayer(name: "Maghrib", time: timings.Maghrib, status: .upcoming),
                Prayer(name: "Isha", time: timings.Isha, status: .upcoming)
            ]
            
            return prayers

        } catch let decodingError as DecodingError {
            throw APIError.decodingError(decodingError)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        } catch {
            throw APIError.networkError(error) // Catch any other unexpected errors
        }
    }
}

// MARK: - API Response Model (Moved here for AladhanAPIService)
// Aladhan API response structure
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
