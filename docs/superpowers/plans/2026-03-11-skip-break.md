# Skip Break Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Skip Break" button that lets the user return to focus mode while the break timer is paused.

**Architecture:** Add `skipToFocus()` to `TimerViewModel` (symmetric to the existing `skipToBreak()`), then add the corresponding "Skip Break" button to `MenuBarView`. Tests go in the existing test file alongside the `skipToBreak` suite.

**Tech Stack:** Swift, SwiftUI, XCTest (macOS menu bar app, Xcode project)

---

## Chunk 1: ViewModel + Tests

### Task 1: Add `skipToFocus()` tests and implementation

**Files:**
- Modify: `sprout-pomodoroTests/sprout_pomodoroTests.swift` (after line 138, after the `skipToBreak` suite)
- Modify: `sprout-pomodoro/TimerViewModel.swift` (after `skipToBreak()`, around line 85)

- [ ] **Step 1: Write the four failing tests**

Open `sprout-pomodoroTests/sprout_pomodoroTests.swift`. After the last `skipToBreak` test (`test_skipToBreak_whenAlreadyInBreak_isNoOp`, ending around line 138), add:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

In Xcode: Product → Test (⌘U), or run the test target from the command line. All four new tests should fail with "use of unresolved identifier 'skipToFocus'".

- [ ] **Step 3: Implement `skipToFocus()` in TimerViewModel**

Open `sprout-pomodoro/TimerViewModel.swift`. After `skipToBreak()` (around line 85), add:

```swift
func skipToFocus() {
    guard mode == .breakTime else { return }
    pause()
    mode = .focus
    remainingSeconds = durationSeconds
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run ⌘U. All four new tests should pass. Existing tests should continue to pass.

- [ ] **Step 5: Commit**

```bash
git add sprout-pomodoro/TimerViewModel.swift sprout-pomodoroTests/sprout_pomodoroTests.swift
git commit -m "feat: add skipToFocus() with tests"
```

---

## Chunk 2: UI

### Task 2: Add "Skip Break" button to MenuBarView

**Files:**
- Modify: `sprout-pomodoro/MenuBarView.swift` (after the "Skip to Break" block, around line 65–72)

- [ ] **Step 1: Add the "Skip Break" button**

Open `sprout-pomodoro/MenuBarView.swift`. After the existing "Skip to Break" block (lines 65–72):

```swift
if viewModel.mode == .focus && !viewModel.isRunning {
    Button("Skip to Break") {
        viewModel.skipToBreak()
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .buttonStyle(.plain)
}
```

Add immediately after:

```swift
if viewModel.mode == .breakTime && !viewModel.isRunning {
    Button("Skip Break") {
        viewModel.skipToFocus()
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .buttonStyle(.plain)
}
```

- [ ] **Step 2: Verify in the app**

Build and run (⌘R). Open the menu bar popup:
- In **focus** mode, pause the timer → "Skip to Break" should appear (existing behaviour unchanged)
- Click "Skip to Break" → switches to break mode, timer paused at full break duration
- "Skip Break" should now appear
- Click "Skip Break" → switches back to focus mode, timer paused at full focus duration
- While the break timer **is running**, neither skip link should appear

- [ ] **Step 3: Commit**

```bash
git add sprout-pomodoro/MenuBarView.swift
git commit -m "feat: add Skip Break button to MenuBarView"
```
