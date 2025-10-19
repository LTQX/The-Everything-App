//
//  AlarmRingingManager.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import Foundation
import AVFoundation
import CoreHaptics
import UIKit
import Combine

@MainActor
final class AlarmRingingManager: ObservableObject {
    static let shared = AlarmRingingManager()

    @Published var isRinging: Bool = false
    @Published var currentText: String = "Wecker klingelt"

    private var audioPlayer: AVAudioPlayer?
    private var hapticEngine: CHHapticEngine?
    private var hapticTimer: Timer?

    private init() {
        prepareHaptics()
        // Audio-Session für Playback
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true, options: [])
    }

    func startRinging(text: String = "Wecker klingelt") {
        currentText = text
        isRinging = true
        startAudioLoop()
        startHapticLoop()
    }

    func stopRinging() {
        isRinging = false
        audioPlayer?.stop()
        audioPlayer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    // MARK: - Audio (Foreground-Alarm)
    private func startAudioLoop() {
        // Für die Foreground-AlarmView darf .m4a genutzt werden
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "m4a") else {
            print("AlarmRingingManager: 'alarm.m4a' nicht im Bundle gefunden.")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            print("AlarmRingingManager Audio error:", error)
        }
    }

    // MARK: - Haptics
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        try? hapticEngine?.start()
    }

    private func startHapticLoop() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticTimer?.invalidate()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in self.pulse() }
        }
        hapticTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func pulse() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
