//
//  CompassService.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

@preconcurrency import CoreLocation
import Foundation
import CoreMotion
import Combine
import UIKit
import CoreHaptics

@MainActor
final class CompassService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = CompassService()

    // Rohdaten & Zustände
    @Published var heading: CLHeading?
    @Published var authState: LocationAuthState = .notDetermined
    @Published var errorMessage: String?

    /// Für das UI: bereits geglätteter und entfalteter Winkel [0, 360)
    @Published var displayHeading: Double = 0

    private let manager = CLLocationManager()
    private let motion = CMMotionManager()

    // EMA auf der Einheitsscheibe (Rauschen entfernen)
    private var emaX: Double?
    private var emaY: Double?
    private let alpha = 0.15  // kleiner = stärker geglättet

    // Zum Entfalten (keine 359→0 Sprünge)
    private var lastRawDeg: Double?

    private override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = kCLHeadingFilterNone
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // Orientation-Änderungen sicher am MainActor behandeln (Selector statt Closure)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Start/Stop/Reset
    func start() {
        guard CLLocationManager.headingAvailable() else {
            errorMessage = "Kompass/Heading nicht verfügbar."
            return
        }
        errorMessage = nil
        applyHeadingOrientation()

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingHeading()
        case .notDetermined:
            manager.startUpdatingHeading() // triggert System-Prompt bei Bedarf
        case .restricted, .denied:
            authState = .denied
        @unknown default:
            authState = .restricted
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    func reset() {
        heading = nil
        errorMessage = nil
        emaX = nil; emaY = nil; lastRawDeg = nil
        displayHeading = 0
    }

    // Orientation → Heading-Frame im LocationManager setzen
    @objc private func handleOrientationChange() {
        applyHeadingOrientation()
    }

    private func applyHeadingOrientation() {
        switch UIDevice.current.orientation {
        case .portrait:               manager.headingOrientation = .portrait
        case .portraitUpsideDown:     manager.headingOrientation = .portraitUpsideDown
        case .landscapeLeft:          manager.headingOrientation = .landscapeLeft
        case .landscapeRight:         manager.headingOrientation = .landscapeRight
        default:                      manager.headingOrientation = .portrait
        }
    }

    // MARK: - Sensor-Test
    struct SensorCheck: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        let details: String
    }

    /// Asynchroner Selbsttest (läuft NICHT am Main-Actor)
    nonisolated func runQuickSensorTest() async -> [SensorCheck] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var checks: [SensorCheck] = []

                let locEnabled = CLLocationManager.locationServicesEnabled()
                checks.append(.init(name: "Location Services",
                                    passed: locEnabled,
                                    details: locEnabled ? "aktiv" : "deaktiviert"))

                let headingAvail = CLLocationManager.headingAvailable()
                checks.append(.init(name: "Heading (Kompass)",
                                    passed: headingAvail,
                                    details: headingAvail ? "verfügbar" : "nicht verfügbar"))

                let motion = CMMotionManager()
                let magnetometerAvail = motion.isMagnetometerAvailable
                checks.append(.init(name: "Magnetometer",
                                    passed: magnetometerAvail,
                                    details: magnetometerAvail ? "verfügbar" : "nicht verfügbar"))

                let gyroAvail = motion.isGyroAvailable
                checks.append(.init(name: "Gyroskop",
                                    passed: gyroAvail,
                                    details: gyroAvail ? "verfügbar" : "nicht verfügbar"))

                let haptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
                checks.append(.init(name: "Haptik",
                                    passed: haptics,
                                    details: haptics ? "unterstützt" : "nicht unterstützt"))

                cont.resume(returning: checks)
            }
        }
    }

    // MARK: - CLLocationManagerDelegate (Callbacks sind nonisolated; hoppen auf MainActor)
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: self.authState = .authorized
            case .denied:       self.authState = .denied
            case .restricted:   self.authState = .restricted
            case .notDetermined:self.authState = .notDetermined
            @unknown default:   self.authState = .restricted
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.heading = newHeading

            // 1) Rohwinkel (true bevorzugen, sonst magnetic)
            let raw = (newHeading.trueHeading >= 0) ? newHeading.trueHeading : newHeading.magneticHeading

            // 2) Entfalten (kleinster Winkelweg)
            let unwrapped: Double
            if let last = lastRawDeg {
                var delta = raw - last
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }
                unwrapped = last + delta
            } else {
                unwrapped = raw
            }
            lastRawDeg = unwrapped

            // 3) EMA auf der Einheitsscheibe (gegen Noise)
            let rad = unwrapped * .pi / 180
            let cx = cos(rad), sy = sin(rad)

            if let ex = emaX, let ey = emaY {
                emaX = (1 - alpha) * ex + alpha * cx
                emaY = (1 - alpha) * ey + alpha * sy
            } else {
                emaX = cx; emaY = sy
            }

            guard let fx = emaX, let fy = emaY else { return }
            var deg = atan2(fy, fx) * 180 / .pi
            if deg < 0 { deg += 360 }

            self.displayHeading = deg
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
