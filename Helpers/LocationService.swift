//
//  LocationService.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    @Published var lastLocation: CLLocation?
    @Published var authState: LocationAuthState = .notDetermined
    @Published var errorMessage: String?
    
    private let manager = CLLocationManager()
    private var pendingOneShot = false
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Authorization
    func requestWhenInUse() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            authState = .authorized
        case .restricted:
            authState = .restricted
        case .denied:
            authState = .denied
        @unknown default:
            authState = .restricted
        }
    }
    
    // MARK: - One-shot location
    func fetchOneShot() {
        requestWhenInUse()
        guard authState == .authorized || manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            return
        }
        errorMessage = nil
        pendingOneShot = true
        manager.requestLocation()
    }
    
    // MARK: - Open Settings
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                self.authState = .authorized
            case .denied:
                self.authState = .denied
            case .restricted:
                self.authState = .restricted
            case .notDetermined:
                self.authState = .notDetermined
            @unknown default:
                self.authState = .restricted
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = loc
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
