# Daily Stats Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show today's completed focus session count and total focus time in the menu bar popover, persisted across restarts and reset at midnight.

**Architecture:** Add three properties (`dailyFocusSessions`, `dailyFocusSeconds`, `statsDate`) to `TimerViewModel` backed by UserDefaults. Session recording and midnight-reset logic live in `tick()`. A computed `formattedDailyTime` property handles display formatting. `MenuBarView` adds a stats row below the Settings/Quit footer.

**Tech Stack:** Swift, SwiftUI, UserDefaults, XCTest

---

## File Map

| File | Change |
|---|---|
| `sprout-pomodoro/TimerViewModel.swift` | Add stats properties, init reset, session recording in `tick()`, midnight reset in `tick()`, `formattedDailyTime` computed property |
| `sprout-pomodoro/MenuBarView.swift` | Add stats row below the footer divider |
| `sprout-pomodoroTests/sprout_pomodoroTests.swift` | Add `DailyStatsTests` class with isolated UserDefaults setUp/tearDown |

---

### Task 1: Add daily stats properties and init reset logic

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift`
- Test: `sprout-pomodoroTests/sprout_pomodoroTests.swift`

- [ ] **Step 1: Write the failing tests**

Add a new test class at the bottom of `sprout-pomodoroTests/sprout_pomodoroTests.swift`:

```swift
// MARK: - Daily Stats Tests

@MainActor
final class DailyStatsTests: XCTestCase {

    private let sessionsKey = "dailyFocusSessions"
    private let secondsKey = "dailyFocusSeconds"
    private let dateKey = "statsDate"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: secondsKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: sessionsKey)
        UserDefaults.standard.removeObject(forKey: secondsKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
        super.tearDown()
    }

    func test_init_dailyStats_areZeroWhenNoStoredData() {
        let vm = TimerViewModel()
        XCTAssertEqual(vm.dailyFocusSessions, 0)
        XCTAssertEqual(vm.dailyFocusSeconds, 0)
    }

    func test_init_resetsStats_whenStoredDateIsNotToday() {
        UserDefaults.standard.set(5, forKey: sessionsKey)
        UserDefaults.standard.set(300, forKey: secondsKey)
        UserDefaults.standard.set("2000-01-01", forKey: dateKey)
        let vm = TimerViewModel()
        XCTAssertEqual(vm.dailyFocusSessions, 0)
        XCTAssertEqual(vm.dailyFocusSeconds, 0)
    }

    func test_init_preservesStats_whenStoredDateIsToday() {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        UserDefaults.standard.set(3, forKey: sessionsKey)
        UserDefaults.standard.set(180, forKey: secondsKey)
        UserDefaults.standard.set(todayString, forKey: dateKey)
        let vm = TimerViewModel()
        XCTAssertEqual(vm.dailyFocusSessions, 3)
        XCTAssertEqual(vm.dailyFocusSeconds, 180)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: compile error — `dailyFocusSessions` and `dailyFocusSeconds` not found on `TimerViewModel`.

- [ ] **Step 3: Add stats properties and init reset logic to TimerViewModel**

Add these three properties after the existing `@Published` declarations (around line 22):

```swift
@Published var dailyFocusSessions: Int = 0
@Published var dailyFocusSeconds: Int = 0
var statsDate: String = ""
```

Add this private helper after `var formattedTime` (around line 39):

```swift
private var todayDateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}
```

Add this private method before `init()`:

```swift
private func resetDailyStats() {
    dailyFocusSessions = 0
    dailyFocusSeconds = 0
    statsDate = todayDateString
    UserDefaults.standard.set(0, forKey: "dailyFocusSessions")
    UserDefaults.standard.set(0, forKey: "dailyFocusSeconds")
    UserDefaults.standard.set(statsDate, forKey: "statsDate")
}
```

At the **end** of `init()`, before the closing `}`, add:

```swift
let storedDate = UserDefaults.standard.string(forKey: "statsDate") ?? ""
if storedDate == todayDateString {
    dailyFocusSessions = UserDefaults.standard.integer(forKey: "dailyFocusSessions")
    dailyFocusSeconds = UserDefaults.standard.integer(forKey: "dailyFocusSeconds")
    statsDate = storedDate
} else {
    resetDailyStats()
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: all three `DailyStatsTests` pass, existing `TimerViewModelTests` still pass.

- [ ] **Step 5: Commit** _(manual — stage and commit these files yourself)_

```
sprout-pomodoro/TimerViewModel.swift
sprout-pomodoroTests/sprout_pomodoroTests.swift
```

---

### Task 2: Record focus sessions in tick()

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift`
- Test: `sprout-pomodoroTests/sprout_pomodoroTests.swift`

- [ ] **Step 1: Write the failing tests**

Add inside the `DailyStatsTests` class:

```swift
func test_tick_whenFocusCompletesNaturally_incrementsSessionCount() {
    let vm = TimerViewModel()
    vm.timerDurationMinutes = 20
    vm.remainingSeconds = 1
    vm.start()
    vm.tick()
    XCTAssertEqual(vm.dailyFocusSessions, 1)
}

func test_tick_whenFocusCompletesNaturally_addsDurationToSeconds() {
    let vm = TimerViewModel()
    vm.timerDurationMinutes = 20
    vm.remainingSeconds = 1
    vm.start()
    vm.tick()
    XCTAssertEqual(vm.dailyFocusSeconds, 20 * 60)
}

func test_tick_multipleCompletions_accumulate() {
    let vm = TimerViewModel()
    vm.timerDurationMinutes = 20
    // First session
    vm.remainingSeconds = 1
    vm.start()
    vm.tick()
    // Switch back to focus and complete again
    vm.mode = .focus
    vm.remainingSeconds = 1
    vm.start()
    vm.tick()
    XCTAssertEqual(vm.dailyFocusSessions, 2)
    XCTAssertEqual(vm.dailyFocusSeconds, 2 * 20 * 60)
}

func test_tick_whenBreakCompletesNaturally_doesNotIncrementSessions() {
    let vm = TimerViewModel()
    vm.mode = .breakTime
    vm.remainingSeconds = 1
    vm.start()
    vm.tick()
    XCTAssertEqual(vm.dailyFocusSessions, 0)
    XCTAssertEqual(vm.dailyFocusSeconds, 0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: the four new tests FAIL (sessions remain 0).

- [ ] **Step 3: Add session recording inside tick()**

In `TimerViewModel.swift`, find the `if remainingSeconds == 0` block inside `tick()`:

```swift
if remainingSeconds == 0 {
    let completedMode = mode
    pause()
    mode = completedMode == .focus ? .breakTime : .focus
    remainingSeconds = durationSeconds
    onFinish?(completedMode)
}
```

Replace it with:

```swift
if remainingSeconds == 0 {
    let completedMode = mode
    if completedMode == .focus {
        dailyFocusSessions += 1
        dailyFocusSeconds += timerDurationMinutes * 60
        UserDefaults.standard.set(dailyFocusSessions, forKey: "dailyFocusSessions")
        UserDefaults.standard.set(dailyFocusSeconds, forKey: "dailyFocusSeconds")
    }
    pause()
    mode = completedMode == .focus ? .breakTime : .focus
    remainingSeconds = durationSeconds
    onFinish?(completedMode)
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: all `DailyStatsTests` pass, all `TimerViewModelTests` still pass.

- [ ] **Step 5: Commit** _(manual — stage and commit these files yourself)_

```
sprout-pomodoro/TimerViewModel.swift
sprout-pomodoroTests/sprout_pomodoroTests.swift
```

---

### Task 3: Add midnight reset in tick()

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift`
- Test: `sprout-pomodoroTests/sprout_pomodoroTests.swift`

- [ ] **Step 1: Write the failing test**

Add inside the `DailyStatsTests` class:

```swift
func test_tick_resetsStats_whenDateHasChangedSinceLastSession() {
    let vm = TimerViewModel()
    // Simulate stats from a previous day
    vm.statsDate = "2000-01-01"
    vm.dailyFocusSessions = 5
    vm.dailyFocusSeconds = 300
    // Note: tick() only guards on remainingSeconds > 0 (not isRunning),
    // so calling it directly without start() is valid here.
    vm.tick()
    XCTAssertEqual(vm.dailyFocusSessions, 0)
    XCTAssertEqual(vm.dailyFocusSeconds, 0)
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: `test_tick_resetsStats_whenDateHasChangedSinceLastSession` FAIL (counts remain 5 and 300).

- [ ] **Step 3: Add date check at the start of tick()**

In `TimerViewModel.swift`, find the `func tick()` method. Add a date check at the very beginning, before the `guard` statement:

```swift
func tick() {
    if todayDateString != statsDate {
        resetDailyStats()
    }
    guard remainingSeconds > 0 else { return }
    // ... rest of method unchanged
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: all tests pass.

- [ ] **Step 5: Commit** _(manual — stage and commit these files yourself)_

```
sprout-pomodoro/TimerViewModel.swift
sprout-pomodoroTests/sprout_pomodoroTests.swift
```

---

### Task 4: Add formattedDailyTime and stats row UI

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift`
- Modify: `sprout-pomodoro/MenuBarView.swift`
- Test: `sprout-pomodoroTests/sprout_pomodoroTests.swift`

- [ ] **Step 1: Write the failing tests**

Add inside `DailyStatsTests`:

```swift
func test_formattedDailyTime_zero_showsZeroMin() {
    let vm = TimerViewModel()
    XCTAssertEqual(vm.formattedDailyTime, "0 min today")
}

func test_formattedDailyTime_underOneHour_showsMinutes() {
    let vm = TimerViewModel()
    vm.dailyFocusSeconds = 2700 // 45 minutes
    XCTAssertEqual(vm.formattedDailyTime, "45 min today")
}

func test_formattedDailyTime_exactlyOneHour_showsHourOnly() {
    let vm = TimerViewModel()
    vm.dailyFocusSeconds = 3600
    XCTAssertEqual(vm.formattedDailyTime, "1h today")
}

func test_formattedDailyTime_overOneHour_showsHoursAndMinutes() {
    let vm = TimerViewModel()
    vm.dailyFocusSeconds = 4800 // 1h 20m
    XCTAssertEqual(vm.formattedDailyTime, "1h 20m today")
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: compile error — `formattedDailyTime` not found.

- [ ] **Step 3: Add formattedDailyTime to TimerViewModel**

Add after `var formattedTime` (around line 39):

```swift
var formattedDailyTime: String {
    let hours = dailyFocusSeconds / 3600
    let mins = (dailyFocusSeconds % 3600) / 60
    if hours > 0 {
        return mins > 0 ? "\(hours)h \(mins)m today" : "\(hours)h today"
    }
    return "\(mins) min today"
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|DailyStats)"
```

Expected: all tests pass.

- [ ] **Step 5: Add stats row to MenuBarView**

In `MenuBarView.swift`, find the Settings/Quit `HStack` at the bottom of the `VStack` and insert a `Divider` and stats `HStack` immediately after it (still inside the VStack, before its closing `}`). The result should look like this:

```swift
            HStack {
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .font(.callout)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .font(.callout)
            }

            Divider()

            HStack {
                Text("🍅 \(viewModel.dailyFocusSessions) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formattedDailyTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
```

- [ ] **Step 6: Build and manually verify**

```bash
xcodebuild build -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`. Open the app and verify the stats row appears below Settings/Quit showing "🍅 0 sessions" and "0 min today".

- [ ] **Step 7: Run full test suite**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:)"
```

Expected: all tests pass.

- [ ] **Step 8: Commit** _(manual — stage and commit these files yourself)_

```
sprout-pomodoro/TimerViewModel.swift
sprout-pomodoro/MenuBarView.swift
sprout-pomodoroTests/sprout_pomodoroTests.swift
```
