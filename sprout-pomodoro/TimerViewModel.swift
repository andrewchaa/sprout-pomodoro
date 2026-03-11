//
//  TimerViewModel.swift
//  sprout-pomodoro
//

import SwiftUI
import Combine

enum TimerMode: Equatable {
    case focus
    case breakTime
}

@MainActor
final class TimerViewModel: ObservableObject {
    @AppStorage("timerDurationMinutes") var timerDurationMinutes: Int = 20 {
        didSet {
            if !isRunning && mode == .focus {
                remainingSeconds = durationSeconds
            }
        }
    }

    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5 {
        didSet {
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
        let savedMinutes = UserDefaults.standard.integer(forKey: "timerDurationMinutes")
        let minutes = savedMinutes > 0 ? savedMinutes : 20
        self.remainingSeconds = minutes * 60
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
