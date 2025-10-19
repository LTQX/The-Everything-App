//
//  CompassTabView.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import SwiftUI
import CoreLocation

struct CompassTabView: View {
    @ObservedObject private var compass = CompassService.shared
    @State private var showChecks = false
    @State private var checks: [CompassService.SensorCheck] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Heading
                    GroupBox {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .strokeBorder(.secondary.opacity(0.2), lineWidth: 2)
                                    .frame(width: 220, height: 220)

                                CompassMarks()

                                // Anzeige: geglätteter Heading
                                CompassNeedle(angle: .degrees(-compass.displayHeading))
                            }
                            .frame(maxWidth: .infinity)
                            .animation(.linear(duration: 0.06), value: compass.displayHeading)

                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    StatusBadge(text: statusText, color: statusColor)
                                    if needsCalibration {
                                        StatusBadge(text: "Kalibrieren empfohlen", color: .orange, icon: "exclamationmark.triangle.fill")
                                    }
                                }

                                Text(headingText)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .monospacedDigit()

                                if let acc = compass.heading?.headingAccuracy, acc > 0 {
                                    Text("Genauigkeit ±\(Int(acc))°")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let err = compass.errorMessage {
                                    Text(err).font(.callout).foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    } label: {
                        Label("Kompass", systemImage: "location.north.line")
                    }

                    // MARK: Controls
                    HStack(spacing: 12) {
                        Button { compass.start() }  label: { Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                        Button { compass.stop() }   label: { Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                        Button { compass.reset() }  label: { Label("Reset", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                    }

                    // MARK: Diagnose
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $showChecks.animation(.easeInOut)) {
                                Label("Sensor-Schnelltest", systemImage: "waveform.path.ecg")
                            }
                            .toggleStyle(.switch)

                            if showChecks {
                                if checks.isEmpty {
                                    ProgressView("Prüfe Sensoren …")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(checks) { c in
                                            HStack {
                                                Text(c.name).font(.subheadline)
                                                Spacer()
                                                Text(c.details)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(c.passed ? .green : .red)
                                            }
                                            .padding(.vertical, 4)
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Diagnose", systemImage: "stethoscope")
                    }
                }
                .padding()
                .navigationTitle("🧭 Kompass")
            }
            .task { checks = await CompassService.shared.runQuickSensorTest() }
        }
    }

    // MARK: - UI Helpers
    private var needsCalibration: Bool {
        if let acc = compass.heading?.headingAccuracy { return acc < 0 || acc > 20 }
        return false
    }

    private var statusText: String {
        switch compass.authState {
        case .authorized: return "Autorisierung: OK"
        case .denied: return "Zugriff verweigert"
        case .restricted: return "Eingeschränkt"
        case .notDetermined: return "Nicht entschieden"
        }
    }

    private var statusColor: Color {
        switch compass.authState {
        case .authorized: return .green
        case .notDetermined: return .orange
        case .denied, .restricted: return .red
        }
    }

    private var headingText: String {
        let deg = Int(compass.displayHeading.rounded())
        return "\(deg)° \(cardinal(from: compass.displayHeading))"
    }

    private func cardinal(from degrees: CLLocationDirection) -> String {
        let dirs = ["N","NE","E","SE","S","SW","W","NW"]
        let idx = Int((degrees + 22.5).truncatingRemainder(dividingBy: 360) / 45.0)
        return dirs[idx]
    }
}

// MARK: - Subviews

private struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) { if let icon { Image(systemName: icon) }; Text(text) }
            .font(.caption.weight(.semibold))
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct CompassMarks: View {
    var body: some View {
        ZStack {
            // Ticks
            ForEach(0..<360, id: \.self) { deg in
                Rectangle()
                    .fill(deg % 30 == 0 ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 2, height: deg % 90 == 0 ? 14 : (deg % 30 == 0 ? 10 : 6))
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(deg)))
            }
            // N/E/S/W – richtige Reihenfolge
            ForEach([(0,"N"),(90,"E"),(180,"S"),(270,"W")], id:\.0) { d, t in
                Text(t)
                    .font(.headline.weight(.bold))
                    .offset(y: -120)
                    .rotationEffect(.degrees(Double(d)))   // positionieren
                    .rotationEffect(.degrees(Double(-d)))  // Text aufrecht
            }
        }
        .frame(width: 240, height: 240)
    }
}

private struct CompassNeedle: View {
    let angle: Angle
    var body: some View {
        ZStack {
            Capsule().fill(Color.red).frame(width: 6, height: 90).offset(y: -45)
            Capsule().fill(Color.blue).frame(width: 6, height: 90).offset(y: 45)
            Circle().fill(.ultraThinMaterial).frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
        }
        .rotationEffect(angle) // Animation kommt vom Parent
    }
}
