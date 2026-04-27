//
//  HapticFeedbackManager.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import UIKit

// Haptik wird nur für wichtige Ereignisse genutzt.
// Nicht dauerhaft, sonst verliert sie ihre Bedeutung.
final class HapticFeedbackManager {
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private var lastHapticTime = Date.distantPast
    private let cooldown: TimeInterval = 1.5

    func targetVeryNear() {
        guard canPlay() else { return }
        impact.impactOccurred()
        lastHapticTime = Date()
    }

    func targetLost() {
        guard canPlay() else { return }
        notification.notificationOccurred(.warning)
        lastHapticTime = Date()
    }

    private func canPlay() -> Bool {
        Date().timeIntervalSince(lastHapticTime) > cooldown
    }
}
