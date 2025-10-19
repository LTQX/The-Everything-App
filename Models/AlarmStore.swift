//
//  AlarmStore.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import Foundation

final class AlarmStore {
    private let key = "alarms_storage_v1"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    func load() -> [Alarm] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? decoder.decode([Alarm].self, from: data)) ?? []
    }
    
    func save(_ alarms: [Alarm]) {
        guard let data = try? encoder.encode(alarms) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
