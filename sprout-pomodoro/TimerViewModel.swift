//
//  TimerViewModel.swift
//  sprout-pomodoro
//

import SwiftUI
import Combine
import SwiftData

enum TimerMode: Sendable, Equatable {
    case focus
    case breakTime
}

@MainActor
final class TimerViewModel: ObservableObject {
    @Published var timerDurationMinutes: Int
    @Published var breakDurationMinutes: Int
    @Published var mode: TimerMode = .focus
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var todaySessions: [FocusSession] = []

    var onFinish: ((TimerMode) -> Void)?

    private var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var isSetUp = false
    private var modelContext: ModelContext?

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

    var dailyFocusSessions: Int { todaySessions.count }

    var formattedDailyTime: String {
        let total = todaySessions.reduce(0) { $0 + $1.durationSeconds }
        let hours = total / 3600
        let mins = (total % 3600) / 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m today" : "\(hours)h today"
        }
        return "\(mins) min today"
    }

    func setupIfNeeded(context: ModelContext, onFinish: @escaping (TimerMode) -> Void) {
        guard !isSetUp else { return }
        isSetUp = true
        self.modelContext = context
        self.onFinish = onFinish
        refreshTodaySessions()
    }

    private func refreshTodaySessions() {
        guard let context = modelContext else { return }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startedAt >= startOfToday }
        )
        do {
            todaySessions = try context.fetch(descriptor)
        } catch {
            print("refreshTodaySessions failed: \(error)")
        }
    }

    init() {
        let savedFocusMins = UserDefaults.standard.integer(forKey: "timerDurationMinutes")
        self.timerDurationMinutes = savedFocusMins > 0 ? savedFocusMins : 20
        let savedBreakMins = UserDefaults.standard.integer(forKey: "breakDurationMinutes")
        self.breakDurationMinutes = savedBreakMins > 0 ? savedBreakMins : 5
        self.remainingSeconds = (savedFocusMins > 0 ? savedFocusMins : 20) * 60

        $timerDurationMinutes
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self = self else { return }
                UserDefaults.standard.set(newValue, forKey: "timerDurationMinutes")
                let newDuration = newValue * 60
                if self.mode == .focus {
                    if !self.isRunning {
                        self.remainingSeconds = newDuration
                    } else if self.remainingSeconds > newDuration {
                        self.remainingSeconds = newDuration
                    }
                }
            }
            .store(in: &cancellables)

        $breakDurationMinutes
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self = self else { return }
                UserDefaults.standard.set(newValue, forKey: "breakDurationMinutes")
                let newDuration = newValue * 60
                if self.mode == .breakTime {
                    if !self.isRunning {
                        self.remainingSeconds = newDuration
                    } else if self.remainingSeconds > newDuration {
                        self.remainingSeconds = newDuration
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellable?.cancel()
        cancellable = nil
        cancellables.removeAll()
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
            if completedMode == .focus, let context = modelContext {
                context.insert(FocusSession(startedAt: Date(), durationSeconds: timerDurationMinutes * 60))
                refreshTodaySessions()
            }
            pause()
            mode = completedMode == .focus ? .breakTime : .focus
            remainingSeconds = durationSeconds
            onFinish?(completedMode)
        }
    }
}
