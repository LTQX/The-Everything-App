//
//  SavedPlaceViewModel.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import Foundation
import CoreLocation
import UIKit
import Combine
import SwiftUI

@MainActor
final class SavedPlacesViewModel: ObservableObject {
    @Published private(set) var places: [SavedPlace] = []
    private let store = SavedPlacesStore()

    init() {
        places = store.load()
    }

    func add(name: String, from location: CLLocation) {
        var arr = places
        arr.append(SavedPlace(name: name, location: location))
        places = arr
        store.save(arr)
        // kleines Feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func delete(at offsets: IndexSet) {
        var arr = places
        arr.remove(atOffsets: offsets)
        places = arr
        store.save(arr)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func json(of place: SavedPlace) -> String {
        place.toPrettyJSON()
    }
}
