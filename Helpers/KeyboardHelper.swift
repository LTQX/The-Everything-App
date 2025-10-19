//
//  KeyboardHelper.swift
//  M335 Everything
//
//  Created by Ylli Kolgeci on 19.10.2025.
//

import SwiftUI
import UIKit

// Globale Funktion zum Schließen der Tastatur
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#endif
