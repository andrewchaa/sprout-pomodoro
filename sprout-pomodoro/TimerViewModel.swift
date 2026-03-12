//
//  TimerViewModel.swift
//  sprout-pomodoro
//

import SwiftUI
import Combine

enum TimerMode: Sendable, Equatable {
    case focus
    case breakTime
}

final class TimerViewModel: ObservableObject {
    @Published var timerDurationMinutes: Int {
        didSet {
            UserDefaults.standard.set(timerDurationMinutes, forKey: "timerDurationMinutes")
            if !isRunning && mode == .focus {
                remainingSeconds = durationSeconds
            }
        }
    }

    @Published var breakDurationMinutes: Int {
        didSet {
            UserDefaults.standard.set(breakDurationMinutes, forKey: "breakDurationMinutes")
            if !isRunning && mode == .breakTime {
                remainingSeconds = durationSeconds
            }
        }
    }

    @Published var mode: TimerMode = .focus
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false

    var onFinish: ((TimerMode) -> Void)?

    private var cancellable: AnyCancellable?

    var durationSeconds: Int {
        switch mode {
        case .focus: return timerDurationMinutes * 60
        case .breakTime: return breakDurationMinutes * 60
        }
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init() {
        let savedFocusMins = UserDefaults.standard.integer(forKey: "timerDurationMinutes")
        self.timerDurationMinutes = savedFocusMins > 0 ? savedFocusMins : 20
        let savedBreakMins = UserDefaults.standard.integer(forKey: "breakDurationMinutes")
        self.breakDurationMinutes = savedBreakMins > 0 ? savedBreakMins : 5
        self.remainingSeconds = (savedFocusMins > 0 ? savedFocusMins : 20) * 60
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pause() {
        isRunning = false
        cancellable?.cancel()
        cancellable = nil
    }

    func reset() {
        pause()
        remainingSeconds = durationSeconds
    }

    func skipToBreak() {
        guard mode == .focus else { return }
        pause()
        mode = .breakTime
        remainingSeconds = durationSeconds
    }

    func skipToFocus() {
        guard mode == .breakTime else { return }
        pause()
        mode = .focus
        remainingSeconds = durationSeconds
    }

    func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            let completedMode = mode
            pause()
            mode = completedMode == .focus ? .breakTime : .focus
            remainingSeconds = durationSeconds
            onFinish?(completedMode)
        }
    }
}
