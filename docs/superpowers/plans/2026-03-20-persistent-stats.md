# Persistent Focus Session Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace UserDefaults-based daily stats with a SwiftData store that persists individual `FocusSession` records permanently, enabling charts, heatmaps, and streak tracking.

**Architecture:** A new `FocusSession` SwiftData model stores one record per completed focus session (`startedAt: Date`, `durationSeconds: Int`). `TimerViewModel` receives a `ModelContext` via `setupIfNeeded(context:onFinish:)` called once from `MenuBarView.onAppear`, inserts a record on each focus completion, and exposes `@Published var todaySessions` as the single source of truth for today's stats display. The old UserDefaults stats properties, midnight-reset logic, and `DailyStatsTests` are all removed.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest

**Spec:** `docs/superpowers/specs/2026-03-20-persistent-stats-design.md`

**Note on commits:** Per project rules, do NOT run `git add` or `git commit` — commit steps are manual.

**Note on Xcode project file:** This project uses `PBXFileSystemSynchronizedRootGroup`. Adding or deleting source files on disk is sufficient — Xcode picks them up automatically. No manual `project.pbxproj` edits are needed for source file changes.

---

## File Map

| File | Change |
|---|---|
| `sprout-pomodoro/FocusSession.swift` | **New** — `@Model final class FocusSession` |
| `sprout-pomodoro/Item.swift` | **Deleted** |
| `sprout-pomodoro/ContentView.swift` | **Deleted** |
| `sprout-pomodoro/TimerViewModel.swift` | Remove UserDefaults stats; add SwiftData integration |
| `sprout-pomodoro/MenuBarView.swift` | Add `@Environment(\.modelContext)`; call `setupIfNeeded` in `onAppear` |
| `sprout-pomodoro/sprout_pomodoroApp.swift` | Add `.modelContainer` to scene; remove `onFinish` from `onAppear` |
| `sprout-pomodoroTests/sprout_pomodoroTests.swift` | Delete `DailyStatsTests`; add `FocusSessionTests`; update `TimerViewModelTests`; add `import SwiftData` |

---

### Task 1: Create FocusSession model and delete unused files

**Files:**
- Create: `sprout-pomodoro/FocusSession.swift`
- Delete: `sprout-pomodoro/Item.swift`
- Delete: `sprout-pomodoro/ContentView.swift`

- [ ] **Step 1: Delete `Item.swift` and `ContentView.swift`**

Both are unused Xcode-generated boilerplate. Delete both files on disk (trash them). Because the project uses `PBXFileSystemSynchronizedRootGroup`, no `project.pbxproj` edits are needed — Xcode reflects the change automatically.

- [ ] **Step 2: Create `sprout-pomodoro/FocusSession.swift`**

```swift
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
```

Drop this file into the `sprout-pomodoro/` directory. The synchronized group picks it up automatically.

- [ ] **Step 3: Build to verify compilation**

```bash
xcodebuild build -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit** _(manual)_

Stage and commit:
```
sprout-pomodoro/FocusSession.swift
sprout-pomodoro/Item.swift          (deleted)
sprout-pomodoro/ContentView.swift   (deleted)
```

---

### Task 2: Write failing tests

**Files:**
- Modify: `sprout-pomodoroTests/sprout_pomodoroTests.swift`

- [ ] **Step 1: Update the test file**

Make all three changes below to `sprout-pomodoroTests/sprout_pomodoroTests.swift` in one edit:

**a) Add `import SwiftData`** at the top, after `import XCTest`.

**b) Delete `DailyStatsTests`** in its entirety (the entire class starting at `// Mark: - Daily Stats Tests` through the closing `}`).

**c) Update `TimerViewModelTests`** — add a `setUp()` and `tearDown()` to inject an in-memory context. Several existing tests drive `tick()` to zero; with the new `tick()` implementation they will attempt to insert a `FocusSession`, so they need a valid context. Add these two methods to the `TimerViewModelTests` class (after the `final class TimerViewModelTests: XCTestCase {` opening line):

```swift
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
```

Then update each test that creates a `TimerViewModel` and drives `tick()` to zero to call `setupIfNeeded` immediately after constructing `vm`. The affected tests are:
- `test_tick_whenReachesZero_setsIsRunningFalse`
- `test_tick_whenReachesZero_callsOnFinish`
- `test_tick_whenFocusEnds_switchesToBreakMode`
- `test_tick_whenFocusEnds_callsOnFinishWithFocusMode`
- `test_tick_whenFocusEnds_resetsToBreakDuration`
- `test_tick_whenBreakEnds_switchesToFocusMode`
- `test_tick_whenBreakEnds_callsOnFinishWithBreakMode`
- `test_tick_whenBreakEnds_resetsToFocusDuration`

For each, add `vm.setupIfNeeded(context: context, onFinish: { _ in })` right after the `let vm = TimerViewModel()` line. Example — `test_tick_whenReachesZero_setsIsRunningFalse` becomes:

```swift
func test_tick_whenReachesZero_setsIsRunningFalse() {
    let vm = TimerViewModel()
    vm.setupIfNeeded(context: context, onFinish: { _ in })
    vm.remainingSeconds = 1
    vm.start()
    vm.tick()
    XCTAssertFalse(vm.isRunning)
}
```

Tests that set `vm.onFinish` directly (e.g. `test_tick_whenReachesZero_callsOnFinish`) should still set `vm.onFinish` after calling `setupIfNeeded`, since `onFinish` is a settable property — the direct assignment overwrites what `setupIfNeeded` stored:

```swift
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
```

Apply the same pattern to all eight affected tests.

**d) Append `FocusSessionTests`** at the bottom of the file:

```swift
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|FocusSession)"
```

Expected: compile error — `value of type 'TimerViewModel' has no member 'setupIfNeeded'` and `value of type 'TimerViewModel' has no member 'formattedDailyTime'`. This confirms the tests are driving the implementation.

---

### Task 3: Implement TimerViewModel changes

**Files:**
- Modify: `sprout-pomodoro/TimerViewModel.swift`

- [ ] **Step 1: Replace the contents of `TimerViewModel.swift`**

```swift
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
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:|FocusSession|TimerViewModel)"
```

Expected: all `FocusSessionTests` pass, all `TimerViewModelTests` still pass.

- [ ] **Step 3: Commit** _(manual)_

Stage and commit:
```
sprout-pomodoro/TimerViewModel.swift
sprout-pomodoroTests/sprout_pomodoroTests.swift
```

---

### Task 4: Wire up the app

**Files:**
- Modify: `sprout-pomodoro/sprout_pomodoroApp.swift`
- Modify: `sprout-pomodoro/MenuBarView.swift`

- [ ] **Step 1: Update `sprout_pomodoroApp.swift`**

Replace the file with:

```swift
//
//  sprout_pomodoroApp.swift
//  sprout-pomodoro
//

import SwiftUI

@main
struct SproutPomodoroApp: App {
    @StateObject private var timerViewModel = TimerViewModel()

    init() {
        DispatchQueue.main.async {
            NSApp?.applicationIconImage = NSImage(named: "AppIcon")
        }
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(timerViewModel)
        } label: {
            RenderedMenuBarLabel(viewModel: timerViewModel)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(for: FocusSession.self)

        Settings {
            SettingsView()
                .environmentObject(timerViewModel)
        }
    }
}
```

`.modelContainer(for: FocusSession.self)` is applied to the `MenuBarExtra` scene (after `.menuBarExtraStyle`), not to `MenuBarView` directly. This injects the container into the entire scene's view hierarchy. The `onAppear` block is removed entirely — `onFinish` and `modelContext` setup now happen in `MenuBarView.onAppear` via `setupIfNeeded`.

- [ ] **Step 2: Update `MenuBarView.swift`**

Replace the entire file with the following (two additions only: `@Environment(\.modelContext)` property and `.onAppear` on the `VStack`; all VStack content is preserved verbatim):

```swift
//
//  MenuBarView.swift
//  sprout-pomodoro
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.mode == .focus ? "Focus" : "Break")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(viewModel.mode == .focus ? Color.orange : Color.green)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(viewModel.formattedTime)
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .monospacedDigit()

            ProgressView(
                value: Double(viewModel.durationSeconds - viewModel.remainingSeconds),
                total: Double(viewModel.durationSeconds)
            )
            .progressViewStyle(.linear)
            .tint(
                viewModel.isRunning
                    ? (viewModel.mode == .focus ? .orange : .green)
                    : .secondary
            )

            HStack(spacing: 16) {
                Button(action: viewModel.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Reset")

                if viewModel.isRunning {
                    Button(action: viewModel.pause) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(viewModel.mode == .focus ? Color.orange : Color.green)
                    }
                    .buttonStyle(.plain)
                    .help("Pause")
                } else {
                    Button(action: viewModel.start) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Start")
                }

                Color.clear
                    .frame(width: 24, height: 24)
            }

            if viewModel.mode == .focus && !viewModel.isRunning {
                Button("Skip to Break") {
                    viewModel.skipToBreak()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            if viewModel.mode == .breakTime && !viewModel.isRunning {
                Button("Skip Break") {
                    viewModel.skipToFocus()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }

            Divider()

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
        }
        .padding(20)
        .frame(width: 260)
        .onAppear {
            viewModel.setupIfNeeded(context: modelContext) { completedMode in
                switch completedMode {
                case .focus:
                    NotificationManager.shared.sendFocusFinishedNotification()
                case .breakTime:
                    NotificationManager.shared.sendBreakFinishedNotification()
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify compilation**

```bash
xcodebuild build -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -project sprout-pomodoro.xcodeproj -scheme sprout-pomodoro -destination 'platform=macOS' 2>&1 | grep -E "(FAILED|PASSED|error:)"
```

Expected: all tests pass.

- [ ] **Step 5: Commit** _(manual)_

Stage and commit:
```
sprout-pomodoro/sprout_pomodoroApp.swift
sprout-pomodoro/MenuBarView.swift
```
