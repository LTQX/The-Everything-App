//
//  SavedPlaceStore.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import Foundation

final class SavedPlacesStore {
    private let key = "saved_places_v1"
    private let enc: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let dec: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func load() -> [SavedPlace] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? dec.decode([SavedPlace].self, from: data)) ?? []
    }

    func save(_ places: [SavedPlace]) {
        guard let data = try? enc.encode(places) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
