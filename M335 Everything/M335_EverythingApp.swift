//
//  M335_EverythingApp.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import SwiftUI
import UserNotifications

@main
struct M335_EverythingApp: App {
    private let notificationDelegate = NotificationDelegate.shared

    init() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                AlarmTabView()
                    .tabItem { Label("Wecker", systemImage: "alarm") }

                LocationTabView()
                    .tabItem { Label("Standort", systemImage: "location") }

                CompassTabView()
                    .tabItem { Label("Kompass", systemImage: "location.north.line") }
            }
            .onAppear {
                // idempotentes Re-Scheduling beim Start
                AlarmViewModel.ensureScheduledOnLaunch()
            }
        }
    }
}
