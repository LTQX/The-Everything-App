//
//  SavedPlace.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import Foundation
import CoreLocation

struct SavedPlace: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var accuracyMeters: Double?
    var savedAt: Date

    init(id: UUID = UUID(),
         name: String,
         location: CLLocation,
         savedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
        self.accuracyMeters = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        self.savedAt = savedAt
    }

    // Für „im Code ansehen“: als hübsches JSON
    func toPrettyJSON() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(self),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
