//
//  AlarmRingingView.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import SwiftUI

struct AlarmRingingView: View {
    @ObservedObject var ringing = AlarmRingingManager.shared
    var onSnooze: (() -> Void)?
    var onStop: (() -> Void)?

    var body: some View {
        ZStack {
            Color.red.opacity(0.1).ignoresSafeArea()
            VStack(spacing: 24) {
                Text(ringing.currentText)
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)

                Image(systemName: "alarm")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)

                HStack(spacing: 16) {
                    Button {
                        onSnooze?()
                    } label: {
                        Label("Snooze 5 Min", systemImage: "zzz")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        ringing.stopRinging()
                        onStop?()
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}
