# Skip Break Design

**Date:** 2026-03-11
**Status:** Approved

## Overview

Add a "Skip Break" option to the Sprout Pomodoro macOS menu bar app. This is the symmetric counterpart to the existing "Skip to Break" feature: when in break mode and the timer is not running, the user can skip back to focus mode immediately.

## Behaviour

- A "Skip Break" link appears in the popup when `mode == .breakTime && !isRunning`
- Tapping it switches to focus mode, resets the focus timer to full duration, and leaves the timer paused
- If already in focus mode, `skipToFocus()` is a no-op (guard-return)
- Matches "Skip to Break" behaviour exactly — only visible when not running

## Architecture

### TimerViewModel

Add `skipToFocus()`, symmetric to the existing `skipToBreak()`:

```swift
func skipToFocus() {
    guard mode == .breakTime else { return }
    pause()
    mode = .focus
    remainingSeconds = durationSeconds
}
```

### MenuBarView

Add a "Skip Break" button below controls, mirroring the existing "Skip to Break" block:

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

## Tests

Four new cases in `TimerViewModelTests`, mirroring the `skipToBreak` suite:

| Test | Setup | Assertion |
|------|-------|-----------|
| `test_skipToFocus_switchesToFocusMode` | `vm.mode = .breakTime` | `mode == .focus` |
| `test_skipToFocus_resetsRemainingToFocusDuration` | `vm.timerDurationMinutes = 25; vm.mode = .breakTime` | `remainingSeconds == 25 * 60` |
| `test_skipToFocus_pausesTimer` | `vm.mode = .breakTime; vm.start()` | `isRunning == false` |
| `test_skipToFocus_whenAlreadyInFocus_isNoOp` | `vm.remainingSeconds = 60` (partial, mode stays `.focus`) | mode unchanged, `remainingSeconds == 60` |

## Files Changed

| File | Change |
|------|--------|
| `TimerViewModel.swift` | Add `skipToFocus()` |
| `MenuBarView.swift` | Add "Skip Break" button (break mode, not running) |
| `sprout_pomodoroTests.swift` | Add 4 `skipToFocus` test cases |

## Out of Scope

- Showing "Skip Break" while the break timer is running
- Any notification on skip
