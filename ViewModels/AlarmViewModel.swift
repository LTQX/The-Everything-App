//
//  AlarmViewModel.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import SwiftUI
import Foundation
import Combine
import UserNotifications
import UIKit

@MainActor
final class AlarmViewModel: ObservableObject {
    @Published var alarms: [Alarm] = []
    private let store = AlarmStore()

    // MARK: - Init
    init() {
        self.alarms = store.load()
    }

    // Beim App-Start aufrufen
    static func ensureScheduledOnLaunch() {
        let vm = AlarmViewModel()
        vm.idempotentReschedule()
    }

    // MARK: - Permissions
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - CRUD
    func add(alarm: Alarm) {
        alarms.append(alarm)
        persistAndReschedule()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func toggle(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(of: alarm) else { return }
        alarms[idx].enabled.toggle()
        persistAndReschedule()
    }

    func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        persistAndReschedule()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func update(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx] = alarm
        persistAndReschedule()
    }

    private func persistAndReschedule() {
        store.save(alarms)
        rescheduleAllNotifications()
    }

    // MARK: – Scheduling (robust & concurrency-safe)
    private func idempotentReschedule() {
        // 1) Snapshot am Main-Actor
        let enabledSnapshot = self.alarms.filter { $0.enabled }

        // 2) Pending lesen (Hintergrund)
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] pending in
            let plannedIDs = Set(pending.map(\.identifier))

            // 3) Nur fehlende Requests planen
            for alarm in enabledSnapshot {
                let ids = AlarmViewModel.ids(for: alarm)
                if !plannedIDs.contains(ids.lead) || !plannedIDs.contains(ids.main) {
                    DispatchQueue.main.async { [weak self] in
                        self?.schedule(alarm)
                    }
                }
            }
        }
    }

    private func rescheduleAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for alarm in alarms where alarm.enabled {
            schedule(alarm)
        }
    }

    // Beide Notifications (Vorwarnung + Haupt-Alarm)
    private func schedule(_ alarm: Alarm) {
        let center = UNUserNotificationCenter.current()

        // 1) Vorwarnung (optional)
        if alarm.leadMinutes > 0 {
            let content = UNMutableNotificationContent()
            content.title = "Wecker"
            content.body  = "Dein Wecker klingelt in \(alarm.leadMinutes) Minuten."
            content.sound = .default
            if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }

            let leadDate  = Calendar.current.date(byAdding: .minute, value: -alarm.leadMinutes, to: alarm.time) ?? alarm.time
            let comps     = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: leadDate)
            let trigger   = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let req = UNNotificationRequest(identifier: AlarmViewModel.ids(for: alarm).lead,
                                            content: content, trigger: trigger)
            center.add(req)
        }

        // 2) Haupt-Alarm (immer)
        let mContent = UNMutableNotificationContent()
        mContent.title = "Wecker"
        mContent.body  = "Dein Wecker klingelt jetzt!"
        // 'alarm.caf' MUSS im Bundle sein (≤ 30 s)
        mContent.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.caf"))
        if #available(iOS 15.0, *) { mContent.interruptionLevel = .timeSensitive }

        let mComps   = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alarm.time)
        let mTrigger = UNCalendarNotificationTrigger(dateMatching: mComps, repeats: false)

        let mReq = UNNotificationRequest(identifier: AlarmViewModel.ids(for: alarm).main,
                                         content: mContent, trigger: mTrigger)
        center.add(mReq)
    }
}

// MARK: - Helper IDs
extension AlarmViewModel {
    nonisolated private static func ids(for alarm: Alarm) -> (lead: String, main: String) {
        (lead: "\(alarm.id.uuidString)-lead",
         main: "\(alarm.id.uuidString)-main")
    }
}
