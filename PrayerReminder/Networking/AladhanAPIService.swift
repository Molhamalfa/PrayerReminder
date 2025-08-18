//
//  AladhanAPIService.swift
//  PrayerReminder
//
//  Created by Mac on 27.07.2025.
//

import Foundation
import CoreLocation

// UPDATED: More specific error cases
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case clientError(Int) // For 4xx errors
    case serverError(Int) // For 5xx errors
    case networkError(Error)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("The API URL is invalid.", comment: "Error description")
        case .noData:
            return NSLocalizedString("No data received from the API.", comment: "Error description")
        case .decodingError:
            return NSLocalizedString("Failed to process the response from the server.", comment: "Error description")
        case .clientError:
            return NSLocalizedString("Could not find prayer times for the specified location. Please check your connection or location settings.", comment: "Error description for client-side errors")
        case .serverError:
            return NSLocalizedString("The prayer time server is currently unavailable. Please try again later.", comment: "Error description for server-side errors")
        case .networkError(let error):
            return NSLocalizedString("Network error: \(error.localizedDescription)", comment: "Error description")
        case .unknownError:
            return NSLocalizedString("An unknown error occurred.", comment: "Error description")
        }
    }
}

class AladhanAPIService {
    func fetchPrayerTimes(latitude: Double, longitude: Double, using timeHelper: PrayerTimeLogicHelper) async throws -> [Prayer] {
        let urlString = "https://api.aladhan.com/v1/timingsByAddress?address=\(latitude),\(longitude)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknownError
            }
            
            // UPDATED: Handle different status code ranges
            switch httpResponse.statusCode {
            case 200...299:
                // Success
                let apiResponse = try JSONDecoder().decode(AladhanResponse.self, from: data)
                guard let timings = apiResponse.data?.timings else { throw APIError.noData }
                
                let initialPrayers = [
                    Prayer(name: "Fajr", time: timings.Fajr, status: .upcoming),
                    Prayer(name: "Sunrise", time: timings.Sunrise, status: .upcoming),
                    Prayer(name: "Dhuhr", time: timings.Dhuhr, status: .upcoming),
                    Prayer(name: "Asr", time: timings.Asr, status: .upcoming),
                    Prayer(name: "Maghrib", time: timings.Maghrib, status: .upcoming),
                    Prayer(name: "Isha", time: timings.Isha, status: .upcoming)
                ]
                
                let prayersWithCorrectStatus = initialPrayers.map { prayer -> Prayer in
                    var correctedPrayer = prayer
                    if timeHelper.hasPrayerWindowEnded(for: prayer, allPrayers: initialPrayers) {
                        correctedPrayer.status = .missed
                    }
                    return correctedPrayer
                }
                
                return prayersWithCorrectStatus
            case 400...499:
                throw APIError.clientError(httpResponse.statusCode)
            case 500...599:
                throw APIError.serverError(httpResponse.statusCode)
            default:
                throw APIError.unknownError
            }

        } catch let decodingError as DecodingError {
            throw APIError.decodingError(decodingError)
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
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
