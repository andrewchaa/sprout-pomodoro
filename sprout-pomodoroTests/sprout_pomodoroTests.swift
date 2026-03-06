//
//  sprout_pomodoroTests.swift
//  sprout-pomodoroTests
//

import XCTest
@testable import sprout_pomodoro

@MainActor
final class TimerViewModelTests: XCTestCase {

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
        vm.remainingSeconds = 1
        vm.start()
        vm.tick()
        XCTAssertFalse(vm.isRunning)
    }

    func test_tick_whenReachesZero_callsOnFinish() {
        let vm = TimerViewModel()
        vm.remainingSeconds = 1
        var finished = false
        vm.onFinish = { finished = true }
        vm.start()
        vm.tick()
        XCTAssertTrue(finished)
    }
}
