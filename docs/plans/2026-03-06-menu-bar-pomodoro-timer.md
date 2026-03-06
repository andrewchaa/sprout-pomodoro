# Menu Bar Pomodoro Timer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the default SwiftUI macOS template into a fully functional menu bar Pomodoro timer with configurable duration and notification support.

**Architecture:** The app lives exclusively in the macOS menu bar using SwiftUI's `MenuBarExtra` scene (macOS 13+). A `TimerViewModel` (ObservableObject) owns all timer state and drives the UI. Notifications are sent via `UserNotifications` framework when the countdown reaches zero.

**Tech Stack:** SwiftUI, MenuBarExtra, UserNotifications, @AppStorage (UserDefaults), Timer.publish, macOS 13+

---

## Pre-flight

Before starting, remove the SwiftData boilerplate that came with the template. These files are unused and will cause confusion.

**Files to delete from the Xcode project (remove reference + file):**
- `sprout-pomodoro/Item.swift`
- `sprout-pomodoro/ContentView.swift`

Do this in Xcode: right-click each file → Delete → Move to Trash.

Also remove SwiftData imports from `sprout_pomodoroApp.swift` (Task 1 rewrites this file entirely).

---

### Task 1: Restructure App Entry Point for Menu Bar

**Goal:** Replace the default WindowGroup with a MenuBarExtra so the app lives only in the menu bar with no Dock icon.

**Files:**
- Rewrite: `sprout-pomodoro/sprout_pomodoroApp.swift`
- Modify: Xcode project Info.plist settings (via Xcode UI)

**Step 1: Rewrite the app entry point**

Replace the entire contents of `sprout_pomodoroApp.swift`:

```swift
import SwiftUI

@main
struct SproutPomodoroApp: App {
    @StateObject private var timerViewModel = TimerViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(timerViewModel)
        } label: {
            TimerMenuBarLabel(viewModel: timerViewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(timerViewModel)
        }
    }
}
```

**Step 2: Hide the Dock icon**

In Xcode:
1. Click the project in the navigator → select the `sprout-pomodoro` target → Info tab
2. Add a new key: `Application is agent (UIElement)` = `YES` (this is `LSUIElement` in Info.plist)

This prevents the app from showing in the Dock or the Cmd+Tab switcher.

**Step 3: Build to verify no compile errors**

In Xcode: Cmd+B
Expected: Build succeeds (it will fail because TimerViewModel/MenuBarView/etc. don't exist yet — that's fine, just verify the app struct compiles cleanly by itself after adding stubs in the next task)

**Step 4: Commit**

```bash
git add sprout-pomodoro/sprout_pomodoroApp.swift
git commit -m "feat: replace WindowGroup with MenuBarExtra for menu bar app"
```

---

### Task 2: TimerViewModel — Core Timer Logic

**Goal:** Create an ObservableObject that owns all timer state: duration, countdown, running/paused states, and fires a notification callback when time runs out.

**Files:**
- Create: `sprout-pomodoro/TimerViewModel.swift`
- Test: `sprout-pomodoroTests/TimerViewModelTests.swift`

**Step 1: Write the failing tests first**

Replace the contents of `sprout-pomodoroTests/sprout_pomodoroTests.swift`:

```swift
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
        vm.tick() // call internal tick manually
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
```

**Step 2: Run tests to verify they fail**

In Xcode: Cmd+U
Expected: Build failure because `TimerViewModel` doesn't exist yet.

**Step 3: Create TimerViewModel**

Create `sprout-pomodoro/TimerViewModel.swift`:

```swift
import SwiftUI
import Combine

@MainActor
final class TimerViewModel: ObservableObject {
    // Persisted setting: timer duration in minutes
    @AppStorage("timerDurationMinutes") var timerDurationMinutes: Int = 20 {
        didSet {
            if !isRunning {
                remainingSeconds = durationSeconds
            }
        }
    }

    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false

    var onFinish: (() -> Void)?

    private var cancellable: AnyCancellable?

    var durationSeconds: Int {
        timerDurationMinutes * 60
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init() {
        // Read persisted duration at init time
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

    /// Called once per second by the timer. Also exposed for testing.
    func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            pause()
            onFinish?()
        }
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Cmd+U
Expected: All 10 tests pass in `TimerViewModelTests`.

**Step 5: Commit**

```bash
git add sprout-pomodoro/TimerViewModel.swift sprout-pomodoroTests/sprout_pomodoroTests.swift
git commit -m "feat: add TimerViewModel with countdown logic and tests"
```

---

### Task 3: MenuBarView — The Popover UI

**Goal:** Create the dropdown UI that appears when the user clicks the menu bar icon. Shows the timer, start/pause/reset buttons, and a link to Settings.

**Files:**
- Create: `sprout-pomodoro/MenuBarView.swift`
- Create: `sprout-pomodoro/TimerMenuBarLabel.swift`

**Step 1: Create TimerMenuBarLabel (the icon in the menu bar)**

Create `sprout-pomodoro/TimerMenuBarLabel.swift`:

```swift
import SwiftUI

struct TimerMenuBarLabel: View {
    @ObservedObject var viewModel: TimerViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.isRunning ? "timer" : "timer")
                .symbolEffect(.pulse, isActive: viewModel.isRunning)
            Text(viewModel.formattedTime)
                .monospacedDigit()
                .font(.system(size: 12, weight: .medium))
        }
    }
}
```

**Step 2: Create MenuBarView**

Create `sprout-pomodoro/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: TimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Timer display
            Text(viewModel.formattedTime)
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .monospacedDigit()

            // Progress ring
            ProgressView(
                value: Double(viewModel.durationSeconds - viewModel.remainingSeconds),
                total: Double(viewModel.durationSeconds)
            )
            .progressViewStyle(.linear)
            .tint(viewModel.isRunning ? .green : .secondary)

            // Controls
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
                            .foregroundStyle(.orange)
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

                // Placeholder for symmetry
                Color.clear
                    .frame(width: 24, height: 24)
            }

            Divider()

            // Footer
            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gear")
                        .font(.callout)
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .font(.callout)
            }
        }
        .padding(20)
        .frame(width: 260)
    }
}
```

**Step 3: Build and visually verify in Xcode**

In Xcode: Cmd+B then Cmd+R
Expected: App appears in menu bar with timer icon and "20:00" text. Clicking it shows the popover with timer display and controls. Start/Pause/Reset should toggle visually (timer won't count yet without notifications being wired — that's fine).

**Step 4: Commit**

```bash
git add sprout-pomodoro/MenuBarView.swift sprout-pomodoro/TimerMenuBarLabel.swift
git commit -m "feat: add menu bar popover UI with timer display and controls"
```

---

### Task 4: Notifications — Permission + Alert on Finish

**Goal:** Request notification permission on launch, and fire a system notification with sound when the Pomodoro timer completes.

**Files:**
- Create: `sprout-pomodoro/NotificationManager.swift`
- Modify: `sprout-pomodoro/sprout_pomodoroApp.swift`

**Step 1: Create NotificationManager**

Create `sprout-pomodoro/NotificationManager.swift`:

```swift
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendTimerFinishedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Complete!"
        content.body = "Time to take a break."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}
```

**Step 2: Wire notifications into the app entry point**

Modify `sprout_pomodoroApp.swift` to request permission on launch and set up the `onFinish` callback:

```swift
import SwiftUI

@main
struct SproutPomodoroApp: App {
    @StateObject private var timerViewModel = TimerViewModel()

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(timerViewModel)
                .onAppear {
                    timerViewModel.onFinish = {
                        NotificationManager.shared.sendTimerFinishedNotification()
                    }
                }
        } label: {
            TimerMenuBarLabel(viewModel: timerViewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(timerViewModel)
        }
    }
}
```

**Step 3: Build and run — test notification manually**

In Xcode: Cmd+R
1. App launches → macOS shows a "Allow notifications?" dialog. Click Allow.
2. In the menu bar popover, set the timer to a very short duration (you'll do this in Settings in Task 5). For now, manually edit `timerDurationMinutes` default to `1` in TimerViewModel's `@AppStorage` default temporarily.
3. Click Start → wait for the timer to reach 0.
4. Expected: A system notification appears with title "Pomodoro Complete!" and a sound plays.

Revert any temporary change after testing.

**Step 4: Commit**

```bash
git add sprout-pomodoro/NotificationManager.swift sprout-pomodoro/sprout_pomodoroApp.swift
git commit -m "feat: add notification on timer completion with sound"
```

---

### Task 5: SettingsView — Configurable Timer Duration

**Goal:** Create a Settings window (accessible via the gear icon or Cmd+,) where the user can adjust the default Pomodoro duration.

**Files:**
- Create: `sprout-pomodoro/SettingsView.swift`

**Step 1: Create SettingsView**

Create `sprout-pomodoro/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TimerViewModel

    // Duration options in minutes
    private let durationOptions = [5, 10, 15, 20, 25, 30, 45, 60]

    var body: some View {
        Form {
            Section {
                Picker("Timer Duration", selection: $viewModel.timerDurationMinutes) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Pomodoro Settings")
            } footer: {
                Text("Changing the duration resets the current timer.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 150)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(TimerViewModel())
}
```

**Step 2: Build and run — test settings**

In Xcode: Cmd+R
1. Open the menu bar popover.
2. Click the gear "Settings" link → Settings window opens.
3. Change duration from 20 minutes to another value.
4. Close settings → menu bar label and popover timer display should show the new duration.
5. The change persists after quitting and relaunching the app.

Expected: Settings window opens, duration picker works, timer resets to new value, and the value is persisted across app launches.

**Step 3: Commit**

```bash
git add sprout-pomodoro/SettingsView.swift
git commit -m "feat: add settings view with configurable timer duration"
```

---

## End-to-End Smoke Test

Run the app and verify all three requirements:

1. **Menu bar presence**: App appears only in the menu bar, no Dock icon, no Cmd+Tab entry.
2. **Configurable timer**: Open Settings (gear icon), change duration, verify timer updates.
3. **Notification + sound**: Start a short timer (set to 1 min in settings), wait for it to complete, verify notification banner appears and a sound plays.

---

## Files Summary

| Action | File |
|--------|------|
| Rewrite | `sprout-pomodoro/sprout_pomodoroApp.swift` |
| Create | `sprout-pomodoro/TimerViewModel.swift` |
| Create | `sprout-pomodoro/MenuBarView.swift` |
| Create | `sprout-pomodoro/TimerMenuBarLabel.swift` |
| Create | `sprout-pomodoro/NotificationManager.swift` |
| Create | `sprout-pomodoro/SettingsView.swift` |
| Rewrite | `sprout-pomodoroTests/sprout_pomodoroTests.swift` |
| Delete | `sprout-pomodoro/Item.swift` (SwiftData boilerplate) |
| Delete | `sprout-pomodoro/ContentView.swift` (SwiftData boilerplate) |
