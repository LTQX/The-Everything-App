//
//  AlarmTabView.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import SwiftUI

struct AlarmTabView: View {
    @StateObject private var vm = AlarmViewModel()
    @ObservedObject private var ringing = AlarmRingingManager.shared

    @State private var newTime: Date = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var leadMinutes: Int = 10
    @State private var showLeadWheel = false

    private let leadOptions: [Int] = [0,5,10,15,20,25,30,45,60]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GroupBox("Neuen Alarm erstellen") {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("Zeit", selection: $newTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)

                        HStack {
                            Text("Vorwarnung")
                            Spacer()
                            Button {
                                showLeadWheel = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                    Text("\(leadMinutes) min")
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            vm.add(alarm: Alarm(time: newTime, leadMinutes: leadMinutes, enabled: true))
                        } label: {
                            Label("Alarm speichern", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                List {
                    ForEach(vm.alarms) { alarm in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(alarm.time.formatted(date: .omitted, time: .shortened))
                                    .font(.title2).bold()
                                Text("Vorwarnung: \(alarm.leadMinutes) min")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding<Bool>(
                                get: { alarm.enabled },
                                set: { newVal in
                                    var edited = alarm
                                    edited.enabled = newVal
                                    vm.update(edited)
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onDelete(perform: vm.delete) // 📳 beim Löschen
                }
            }
            .padding()
            .navigationTitle("⏰ Wecker")
            .onAppear { vm.requestNotificationPermission() }
            .sheet(isPresented: $showLeadWheel) {
                NavigationStack {
                    VStack {
                        Picker("Vorwarnung (Minuten)", selection: $leadMinutes) {
                            ForEach(leadOptions, id: \.self) { m in
                                Text("\(m) Minuten").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 180)
                        .padding(.top, 12)

                        Text("Aktuell: \(leadMinutes) min")
                            .font(.headline)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .navigationTitle("Vorwarnung")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { showLeadWheel = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            // Vollbild-Alarm anzeigen, wenn klingelt
            .fullScreenCover(isPresented: $ringing.isRinging) {
                AlarmRingingView(
                    onSnooze: {
                        ringing.stopRinging()
                        // Snooze 5 Min: plane neue Notification in 5 Minuten
                        let newDate = Date().addingTimeInterval(5 * 60)
                        let alarm = Alarm(time: newDate, leadMinutes: 0, enabled: true)
                        vm.add(alarm: alarm)
                    },
                    onStop: {
                        // nichts weiter – Ton/Haptik wurden gestoppt
                    }
                )
            }
        }
    }
}
