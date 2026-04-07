//
//  sprout_pomodoroTests.swift
//  sprout-pomodoroTests
//

import XCTest
import SwiftData
@testable import sprout_pomodoro

@MainActor
final class TimerViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: FocusSession.self, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    func test_initialState_isNotRunning() {
        let vm = TimerViewModel()
        XCTAssertFalse(vm.isRunning)
    }

    func test_initialState_remainingTimeEqualsDuration() {
        let vm = TimerViewModel()
        XCTAssertEqual(vm.remainingSeconds, vm.durationSeconds)
    }

    func test_start_setsIsRunningTrue() {
        let vm = TimerViewModel()
        vm.start()
        XCTAssertTrue(vm.isRunning)
    }

    func test_pause_setsIsRunningFalse() {
        let vm = TimerViewModel()
        vm.start()
        vm.pause()
        XCTAssertFalse(vm.isRunning)
    }

    func test_reset_restoresRemainingToFull() {
        let vm = TimerViewModel()
        vm.start()
        vm.remainingSeconds = 30
        vm.reset()
        XCTAssertEqual(vm.remainingSeconds, vm.durationSeconds)
        XCTAssertFalse(vm.isRunning)
    }

    func test_formattedTime_showsMMSS() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 125 // 2:05
        XCTAssertEqual(vm.formattedTime, "02:05")
    }

    func test_formattedTime_showsZero() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 0
        XCTAssertEqual(vm.formattedTime, "00:00")
    }

    func test_tick_decrementsRemainingSeconds() {
        let vm = TimerViewModel()
        vm.start()
        let before = vm.remainingSeconds
        vm.tick()
        XCTAssertEqual(vm.remainingSeconds, before - 1)
    }

    func test_tick_doesNotDecrementBelowZero() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 0
        vm.tick()
        XCTAssertEqual(vm.remainingSeconds, 0)
    }

    func test_tick_whenReachesZero_setsIsRunningFalse() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertFalse(vm.isRunning)
    }

    func test_tick_whenReachesZero_callsOnFinish() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.remainingSeconds = 1
        var finished = false
        vm.onFinish = { _ in finished = true }
        vm.start()
        vm.tick()
        XCTAssertTrue(finished)
    }

    // MARK: - Mode tests

    func test_initialMode_isFocus() {
        let vm = TimerViewModel()
        XCTAssertEqual(vm.mode, .focus)
    }

    func test_durationSeconds_inFocusMode_usesFocusDuration() {
        let vm = TimerViewModel()
        vm.timerDurationMinutes = 25
        XCTAssertEqual(vm.durationSeconds, 25 * 60)
    }

    func test_durationSeconds_inBreakMode_usesBreakDuration() {
        let vm = TimerViewModel()
        vm.skipToBreak()
        XCTAssertEqual(vm.durationSeconds, vm.breakDurationMinutes * 60)
    }

    func test_skipToBreak_switchesToBreakMode() {
        let vm = TimerViewModel()
        vm.skipToBreak()
        XCTAssertEqual(vm.mode, .breakTime)
    }

    func test_skipToBreak_resetsRemainingToBreakDuration() {
        let vm = TimerViewModel()
        vm.breakDurationMinutes = 5
        vm.skipToBreak()
        XCTAssertEqual(vm.remainingSeconds, 5 * 60)
    }

    func test_skipToBreak_pausesTimer() {
        let vm = TimerViewModel()
        vm.start()
        vm.skipToBreak()
        XCTAssertFalse(vm.isRunning)
    }

    func test_skipToBreak_whenAlreadyInBreak_isNoOp() {
        let vm = TimerViewModel()
        vm.skipToBreak()       // enter break mode via API
        vm.remainingSeconds = 60  // partially elapsed
        vm.skipToBreak()       // should be a no-op
        // mode unchanged, remainingSeconds unchanged
        XCTAssertEqual(vm.mode, .breakTime)
        XCTAssertEqual(vm.remainingSeconds, 60)
    }

    // MARK: - skipToFocus tests

    func test_skipToFocus_switchesToFocusMode() {
        let vm = TimerViewModel()
        vm.mode = .breakTime
        vm.skipToFocus()
        XCTAssertEqual(vm.mode, .focus)
    }

    func test_skipToFocus_resetsRemainingToFocusDuration() {
        let vm = TimerViewModel()
        vm.timerDurationMinutes = 25
        vm.mode = .breakTime
        vm.skipToFocus()
        XCTAssertEqual(vm.remainingSeconds, 25 * 60)
    }

    func test_skipToFocus_pausesTimer() {
        let vm = TimerViewModel()
        vm.mode = .breakTime
        vm.start()
        vm.skipToFocus()
        XCTAssertFalse(vm.isRunning)
    }

    func test_skipToFocus_whenAlreadyInFocus_isNoOp() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 60  // partial — mode stays .focus by default
        vm.skipToFocus()
        XCTAssertEqual(vm.mode, .focus)
        XCTAssertEqual(vm.remainingSeconds, 60)
    }

    func test_reset_inBreakMode_staysInBreakMode() {
        let vm = TimerViewModel()
        vm.skipToBreak()       // enter break mode via API
        vm.remainingSeconds = 30
        vm.reset()
        XCTAssertEqual(vm.mode, .breakTime)
        XCTAssertEqual(vm.remainingSeconds, vm.breakDurationMinutes * 60)
    }

    func test_tick_whenFocusEnds_switchesToBreakMode() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.mode, .breakTime)
    }

    func test_tick_whenFocusEnds_callsOnFinishWithFocusMode() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.remainingSeconds = 1
        var completedMode: TimerMode?
        vm.onFinish = { completedMode = $0 }
        vm.start()
        vm.tick()
        XCTAssertEqual(completedMode, .focus)
    }

    func test_tick_whenFocusEnds_resetsToBreakDuration() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.breakDurationMinutes = 5
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.remainingSeconds, 5 * 60)
        XCTAssertFalse(vm.isRunning)
    }

    func test_tick_whenBreakEnds_switchesToFocusMode() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.mode = .breakTime
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.mode, .focus)
    }

    func test_tick_whenBreakEnds_callsOnFinishWithBreakMode() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.mode = .breakTime
        vm.remainingSeconds = 1
        var completedMode: TimerMode?
        vm.onFinish = { completedMode = $0 }
        vm.start()
        vm.tick()
        XCTAssertEqual(completedMode, .breakTime)
    }

    func test_tick_whenBreakEnds_resetsToFocusDuration() {
        let vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
        vm.timerDurationMinutes = 25
        vm.mode = .breakTime
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.remainingSeconds, 25 * 60)
        XCTAssertFalse(vm.isRunning)
    }
}

// MARK: - Focus Session Tests

@MainActor
final class FocusSessionTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var vm: TimerViewModel!

    override func setUp() async throws {
        try await super.setUp()
        // Clear UserDefaults timer settings so tests start from a known state
        UserDefaults.standard.removeObject(forKey: "timerDurationMinutes")
        UserDefaults.standard.removeObject(forKey: "breakDurationMinutes")
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: FocusSession.self, configurations: config)
        context = container.mainContext
        vm = TimerViewModel()
        vm.setupIfNeeded(context: context, onFinish: { _ in })
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "timerDurationMinutes")
        UserDefaults.standard.removeObject(forKey: "breakDurationMinutes")
        vm = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    func test_tick_whenFocusCompletesNaturally_insertsSession() throws {
        vm.timerDurationMinutes = 20
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions.count, 1)
    }

    func test_tick_whenFocusCompletesNaturally_sessionHasCorrectDuration() throws {
        vm.timerDurationMinutes = 20
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions.first?.durationSeconds, 20 * 60)
    }

    func test_tick_whenBreakCompletesNaturally_doesNotInsertSession() throws {
        vm.mode = .breakTime
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions.count, 0)
    }

    func test_tick_multipleCompletions_accumulateSessions() throws {
        vm.timerDurationMinutes = 20
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        vm.mode = .focus
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(sessions.count, 2)
    }

    func test_dailyFocusSessions_countsTodaySessions() {
        vm.timerDurationMinutes = 20
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.dailyFocusSessions, 1)
    }

    func test_formattedDailyTime_zero_showsZeroMin() {
        XCTAssertEqual(vm.formattedDailyTime, "0 min today")
    }

    func test_formattedDailyTime_underOneHour_showsMinutes() {
        vm.timerDurationMinutes = 45
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.formattedDailyTime, "45 min today")
    }

    func test_formattedDailyTime_exactlyOneHour_showsHourOnly() {
        vm.timerDurationMinutes = 60
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertEqual(vm.formattedDailyTime, "1h today")
    }

    func test_formattedDailyTime_overOneHour_showsHoursAndMinutes() {
        vm.timerDurationMinutes = 20
        for _ in 0..<4 {
            vm.mode = .focus
            vm.remainingSeconds = 1
            vm.start()
            vm.tick()
        }
        // 4 × 20 min = 80 min = 1h 20m
        XCTAssertEqual(vm.formattedDailyTime, "1h 20m today")
    }

    func test_refreshTodaySessions_excludesPreviousDaySessions() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        context.insert(FocusSession(startedAt: yesterday, durationSeconds: 20 * 60))
        // Trigger a today completion to force a refreshTodaySessions call
        vm.timerDurationMinutes = 20
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        // Only the today session should be in todaySessions
        XCTAssertEqual(vm.dailyFocusSessions, 1)
    }

    func test_refreshTodaySessions_directCall_excludesYesterdaySessions() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        context.insert(FocusSession(startedAt: yesterday, durationSeconds: 20 * 60))
        try context.save()

        vm.refreshTodaySessions()

        XCTAssertEqual(vm.dailyFocusSessions, 0)
    }
}
