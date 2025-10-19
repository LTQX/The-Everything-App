//
//  LocationTabView.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import SwiftUI
import CoreLocation
import MapKit

// ✅ Kleiner Wrapper statt String:Identifiable
struct JSONPayload: Identifiable {
    let id = UUID()
    let text: String
}

struct LocationTabView: View {
    @StateObject private var service = LocationService.shared
    @StateObject private var savedVM = SavedPlacesViewModel()

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var saveName: String = ""
    @State private var jsonToShow: JSONPayload?     // ✅ Wrapper statt String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Karte
                    GroupBox("Karte") {
                        Map(position: $mapPosition) {
                            if let loc = service.lastLocation {
                                UserAnnotation()
                                Annotation("Du", coordinate: loc.coordinate) {
                                    Image(systemName: "mappin.circle.fill").font(.title)
                                }
                            }
                        }
                        .mapStyle(.standard)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onChange(of: service.lastLocation) { _, new in
                            if let new {
                                withAnimation {
                                    mapPosition = .region(
                                        MKCoordinateRegion(
                                            center: new.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        )
                                    )
                                }
                            }
                        }
                    }

                    // Details
                    GroupBox("Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let loc = service.lastLocation {
                                let c = loc.coordinate
                                HStack { Text("Breite:");      Spacer(); Text(String(format: "%.6f", c.latitude)) }
                                HStack { Text("Länge:");       Spacer(); Text(String(format: "%.6f", c.longitude)) }
                                HStack { Text("Genauigkeit:"); Spacer(); Text("\(Int(loc.horizontalAccuracy)) m") }
                                HStack { Text("Höhe:");        Spacer(); Text("\(Int(loc.altitude)) m") }
                                HStack { Text("Zeit:");        Spacer(); Text(loc.timestamp.formatted(date: .abbreviated, time: .standard)) }
                            } else {
                                Text("Noch kein Standort ermittelt.").foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Aktionen
                    GroupBox("Aktionen") {
                        VStack(spacing: 12) {
                            switch service.authState {
                            case .authorized:
                                Button {
                                    service.fetchOneShot()
                                } label: {
                                    Label("Standort holen", systemImage: "location.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                // Speichern
                                HStack {
                                    TextField("Ort speichern als … (z. B. Zuhause)", text: $saveName)
                                        .textFieldStyle(.roundedBorder)
                                    Button {
                                        if let loc = service.lastLocation,
                                           !saveName.trimmingCharacters(in: .whitespaces).isEmpty {
                                            savedVM.add(name: saveName.trimmingCharacters(in: .whitespaces), from: loc)
                                            saveName = ""
                                            hideKeyboard()
                                        }
                                    } label: {
                                        Image(systemName: "tray.and.arrow.down.fill")
                                    }
                                    .disabled(service.lastLocation == nil || saveName.trimmingCharacters(in: .whitespaces).isEmpty)
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityLabel("Ort speichern")
                                }

                            case .notDetermined:
                                Button {
                                    service.requestWhenInUse()
                                } label: {
                                    Label("Zugriff erlauben", systemImage: "hand.raised.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                            case .denied, .restricted:
                                VStack(spacing: 8) {
                                    Text("Standortzugriff ist deaktiviert.").foregroundStyle(.secondary)
                                    Button {
                                        service.openSettings()
                                    } label: {
                                        Label("Zu den Einstellungen", systemImage: "gear")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            if let err = service.errorMessage {
                                Text("Fehler: \(err)").font(.footnote).foregroundStyle(.red)
                            }
                        }
                    }

                    // Gespeicherte Orte
                    GroupBox("Gespeicherte Orte (\(savedVM.places.count))") {
                        if savedVM.places.isEmpty {
                            Text("Noch keine Orte gespeichert.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(savedVM.places) { place in
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(place.name).font(.headline)
                                            Text(String(format: "Lat: %.6f  Lon: %.6f", place.latitude, place.longitude))
                                                .font(.caption).foregroundStyle(.secondary).monospaced()
                                            Text("Gespeichert: \(place.savedAt.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Menu {
                                            Button("JSON anzeigen") {
                                                jsonToShow = JSONPayload(text: savedVM.json(of: place))   // ✅ Wrapper
                                            }
                                            Button(role: .destructive) {
                                                if let idx = savedVM.places.firstIndex(of: place) {
                                                    savedVM.delete(at: IndexSet(integer: idx))
                                                }
                                            } label: {
                                                Label("Löschen", systemImage: "trash")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.title3)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("📍 Wo bin ich?")
            .onAppear { service.requestWhenInUse() }
            // ✅ Sheet mit Wrapper statt String:Identifiable
            .sheet(item: $jsonToShow) { payload in
                NavigationStack {
                    ScrollView {
                        Text(payload.text)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .textSelection(.enabled)
                            .gesture(
                                TapGesture().onEnded {
                                    hideKeyboard()
                                }
                            )
                    }
                    .navigationTitle("Gespeicherter Ort (JSON)")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { jsonToShow = nil }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                UIPasteboard.general.string = payload.text
                            } label: {
                                Label("Kopieren", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}
