//
//  Alarm.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var time: Date
    var leadMinutes: Int
    var enabled: Bool

    init(id: UUID = UUID(), time: Date, leadMinutes: Int = 10, enabled: Bool = true) {
        self.id = id
        self.time = time
        self.leadMinutes = leadMinutes
        self.enabled = enabled
    }
}
