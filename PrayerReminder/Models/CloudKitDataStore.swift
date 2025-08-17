//
//  CloudKitDataStore.swift
//  PrayerReminder
//
//  Created by Mac on 28.07.2025.
//

import Foundation
import CloudKit

/// Manages all interactions with the user's private CloudKit database.
/// This class is responsible for saving, fetching, and updating prayer history data.
class CloudKitDataStore {
    
    // MARK: - Properties
    
    // The default container for the app.
    private let container = CKContainer.default()
    
    // The user's private database, where all their data is stored securely.
    private var database: CKDatabase {
        return container.privateCloudDatabase
    }
    
    // A constant for the record type we'll use in CloudKit.
    private let recordType = "SavedPrayerData"
    
    // MARK: - Public Methods
    
    /// Saves or updates a day's prayer data to CloudKit.
    /// It first queries to see if a record for the given date already exists.
    /// If it exists, it updates the record. If not, it creates a new one.
    /// - Parameter savedPrayerData: The `SavedPrayerData` object to be saved.
    func save(_ savedPrayerData: SavedPrayerData) async throws {
        let recordID = CKRecord.ID(recordName: savedPrayerData.date)
        
        do {
            // Try to fetch an existing record with the same ID (date string)
            let existingRecord = try await database.record(for: recordID)
            
            // If it exists, update it.
            let updatedRecord = update(record: existingRecord, with: savedPrayerData)
            _ = try await database.save(updatedRecord)
            print("☁️ CloudKit: Successfully updated record for date: \(savedPrayerData.date)")
            
        } catch let error as CKError where error.code == .unknownItem {
            // If the record is not found (.unknownItem), create a new one
            let newRecord = createRecord(from: savedPrayerData)
            _ = try await database.save(newRecord)
            print("☁️ CloudKit: Successfully saved new record for date: \(savedPrayerData.date)")
            
        } catch {
            // Handle other potential errors during fetch or save
            print("❌ CloudKit: Error saving or updating record for date \(savedPrayerData.date): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetches all historical prayer data from CloudKit.
    /// - Returns: An array of `SavedPrayerData` objects, sorted by date descending.
    func fetchAllPrayerData() async throws -> [SavedPrayerData] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        // Execute the query to get matching records.
        let (matchResults, _) = try await database.records(matching: query)
        
        var savedData: [SavedPrayerData] = []
        
        // CORRECTED: Use a standard for-in loop, as `matchResults` is a regular Array, not an AsyncSequence.
        for (_, result) in matchResults {
            // We still use `try` here to extract the value from the `Result` type, which can throw an error.
            let record = try result.get()
            if let data = try parseRecord(record) {
                savedData.append(data)
            }
        }
        
        print("☁️ CloudKit: Successfully fetched \(savedData.count) historical records.")
        return savedData
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates a new `CKRecord` from a `SavedPrayerData` model object.
    private func createRecord(from savedPrayerData: SavedPrayerData) -> CKRecord {
        let recordID = CKRecord.ID(recordName: savedPrayerData.date)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        return update(record: record, with: savedPrayerData)
    }
    
    /// Updates an existing `CKRecord` with data from a `SavedPrayerData` model object.
    private func update(record: CKRecord, with savedPrayerData: SavedPrayerData) -> CKRecord {
        record["date"] = savedPrayerData.date as CKRecordValue
        
        // Encode the array of `Prayer` objects into JSON data to store in CloudKit.
        if let prayersData = try? JSONEncoder().encode(savedPrayerData.prayers) {
            record["prayersData"] = prayersData as CKRecordValue
        }
        
        return record
    }
    
    /// Parses a `CKRecord` fetched from CloudKit back into a `SavedPrayerData` model object.
    private func parseRecord(_ record: CKRecord) throws -> SavedPrayerData? {
        guard let date = record["date"] as? String,
              let prayersData = record["prayersData"] as? Data else {
            return nil
        }
        
        // Decode the JSON data back into an array of `Prayer` objects.
        let prayers = try JSONDecoder().decode([Prayer].self, from: prayersData)
        return SavedPrayerData(date: date, prayers: prayers)
    }
}
