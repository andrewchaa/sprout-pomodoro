# First-Open-of-Day Focus Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the user opens the menu bar popup for the first time in a day and no timer is running, always show the Focus screen instead of whatever mode was active yesterday.

**Architecture:** Add a `resetToFocusIfFirstOpenOfDay(defaults:)` method to `TimerViewModel` that compares today's date against a persisted "last popup opened date" in UserDefaults, then calls `skipToFocus()` if a new day is detected and the timer is idle. Call this method from `MenuBarView.onAppear`.

**Tech Stack:** Swift, SwiftUI, Combine, XCTest, UserDefaults

---

## File Map

| File | Change |
|------|--------|
| `sprout-pomodoro/TimerViewModel.swift` | Add `resetToFocusIfFirstOpenOfDay(defaults:)` method |
| `sprout-pomodoro/MenuBarView.swift` | Call the new method inside `.onAppear` |
| `sprout-pomodoroTests/sprout_pomodoroTests.swift` | Add `FirstOpenOfDayTests` class |

---

### Task 1: Write failing tests for `resetToFocusIfFirstOpenOfDay`

**Files:**
- Modify: `sprout-pomodoroTests/sprout_pomodoroTests.swift` (append after the last `}`)

- [ ] **Step 1: Append the new test class to the test file**

Add this block at the very end of `sprout-pomodoroTests/sprout_pomodoroTests.swift`, after the closing `}` of `FocusSessionTests`:

```swift
// MARK: - First Open Of Day Tests

@MainActor
final class FirstOpenOfDayTests: XCTestCase {
    let suiteName = "FirstOpenOfDayTests"
    let key = "lastPopupOpenedDate"
    var defaults: UserDefaults!
    var vm: TimerViewModel!

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removeObject(forKey: key)
        vm = TimerViewModel()
    }

    override func tearDown() async throws {
        defaults.removeSuite(named: suiteName)
        defaults = nil
        vm = nil
        try await super.tearDown()
    }

    func test_firstOpenOfDay_whenBreakModeAndIdle_resetsToFocus() {
        vm.mode = .breakTime
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
            to: Calendar.current.startOfDay(for: Date()))!
        defaults.set(yesterday, forKey: key)

        vm.resetToFocusIfFirstOpenOfDay(defaults: defaults)

        XCTAssertEqual(vm.mode, .focus)
    }

    func test_firstOpenOfDay_whenBreakModeAndTimerRunning_doesNotReset() {
        vm.mode = .breakTime
        vm.isRunning = true
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
            to: Calendar.current.startOfDay(for: Date()))!
        defaults.set(yesterday, forKey: key)

        vm.resetToFocusIfFirstOpenOfDay(defaults: defaults)

        XCTAssertEqual(vm.mode, .breakTime)
    }

    func test_firstOpenOfDay_whenAlreadyOpenedToday_doesNotReset() {
        vm.mode = .breakTime
        let today = Calendar.current.startOfDay(for: Date())
        defaults.set(today, forKey: key)

        vm.resetToFocusIfFirstOpenOfDay(defaults: defaults)

        XCTAssertEqual(vm.mode, .breakTime)
    }

    func test_firstOpenOfDay_whenNoPreviousDate_resetsToFocus() {
        vm.mode = .breakTime

        vm.resetToFocusIfFirstOpenOfDay(defaults: defaults)

        XCTAssertEqual(vm.mode, .focus)
    }

    func test_firstOpenOfDay_savesTodayAsLastOpenedDate() {
        vm.resetToFocusIfFirstOpenOfDay(defaults: defaults)

        let saved = defaults.object(forKey: key) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(saved, today)
    }

    func test_firstOpenOfDay_whenTimerRunning_stillSavesToday() {
        vm.mode = .breakTime
        vm.isRunning = true
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
            to: Calendar.current.startOfDay(for: Date()))!
        defaults.set(yesterday, forKey: key)

        vm.resetToFocusIfFirstOpenOfDay(defaults: defaults)

        let saved = defaults.object(forKey: key) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(saved, today)
    }
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
xcodebuild test \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  -only-testing:sprout-pomodoroTests/FirstOpenOfDayTests \
  2>&1 | grep -E "(FAILED|error:|Build succeeded|Build FAILED)"
```

Expected: Build may succeed but tests fail with `error: use of unresolved identifier 'resetToFocusIfFirstOpenOfDay'`.

---

### Task 2: Implement `resetToFocusIfFirstOpenOfDay` in `TimerViewModel`

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift` (add method before the closing `}` of the class, after `tick()`)

- [ ] **Step 3: Add the method to TimerViewModel**

Insert the following after `tick()` (after line 172, before the final `}`):

```swift
    func resetToFocusIfFirstOpenOfDay(defaults: UserDefaults = .standard) {
        let today = Calendar.current.startOfDay(for: Date())
        defer { defaults.set(today, forKey: "lastPopupOpenedDate") }

        if let lastOpened = defaults.object(forKey: "lastPopupOpenedDate") as? Date,
           lastOpened >= today {
            return
        }

        guard !isRunning else { return }
        skipToFocus()
    }
```

**How it works:**
- `defer` always saves today's start-of-day, even when returning early (so subsequent opens today are skipped).
- If `lastOpened >= today` the popup was already opened today → no-op.
- If the timer is running (active focus or break session) → no-op, but today is still saved.
- Otherwise calls `skipToFocus()`. That method has its own `guard mode == .breakTime` so if already in focus mode it is harmlessly a no-op.

- [ ] **Step 4: Run the tests to confirm they now pass**

```bash
xcodebuild test \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  -only-testing:sprout-pomodoroTests/FirstOpenOfDayTests \
  2>&1 | grep -E "(FAILED|passed|error:|Build succeeded|Build FAILED)"
```

Expected: All 6 tests pass.

- [ ] **Step 5: Run the full test suite to confirm no regressions**

```bash
xcodebuild test \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(FAILED|passed|error:|Build succeeded|Build FAILED)"
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add sprout-pomodoro/TimerViewModel.swift sprout-pomodoroTests/sprout_pomodoroTests.swift
git commit -m "feat: reset to focus on first popup open of the day

If the app is opened for the first time today and no timer is active,
resetToFocusIfFirstOpenOfDay switches mode back to .focus so the user
always starts their day on the Focus screen."
```

---

### Task 3: Wire the reset into `MenuBarView.onAppear`

**Files:**
- Modify: `sprout-pomodoro/MenuBarView.swift` (inside `.onAppear`, lines 139–150)

- [ ] **Step 7: Add the call inside `.onAppear`**

Replace the existing `.onAppear` block (lines 139–150) with:

```swift
        .onAppear {
            viewModel.setupIfNeeded(context: modelContext) { completedMode in
                switch completedMode {
                case .focus:
                    NotificationManager.shared.sendFocusFinishedNotification()
                case .breakTime:
                    NotificationManager.shared.sendBreakFinishedNotification()
                }
            }
            viewModel.resetToFocusIfFirstOpenOfDay()
            viewModel.refreshTodaySessions()
            updateChecker.startPeriodicChecks()
        }
```

- [ ] **Step 8: Build to confirm no compile errors**

```bash
xcodebuild build \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|Build succeeded|Build FAILED)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add sprout-pomodoro/MenuBarView.swift
git commit -m "feat: call resetToFocusIfFirstOpenOfDay when menu bar popup opens"
```

---

## Self-Review

**Spec coverage:**
- ✅ First open of the day → Focus screen shown (Tasks 2 + 3)
- ✅ Active timer not interrupted (guard `!isRunning` in Task 2)
- ✅ Subsequent opens the same day unaffected (date comparison via `defer` in Task 2)
- ✅ Tested: break→focus reset, running timer guard, same-day guard, nil date, date persistence (Task 1)

**Placeholder scan:** No TBDs, TODOs, or vague steps. All code is complete.

**Type consistency:** `resetToFocusIfFirstOpenOfDay(defaults:)` is referenced identically in tests (Task 1) and implementation (Task 2). `"lastPopupOpenedDate"` key string is the same in implementation and all tests. `TimerMode.focus` / `.breakTime` match the enum defined in `TimerViewModel.swift`.
