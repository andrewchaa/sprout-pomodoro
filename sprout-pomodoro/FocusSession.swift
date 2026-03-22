//
//  FocusSession.swift
//  sprout-pomodoro
//

import Foundation
import SwiftData

@Model
final class FocusSession {
    var startedAt: Date
    var durationSeconds: Int

    init(startedAt: Date, durationSeconds: Int) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
    }
}
