# Daily Stats Display — Design Spec

**Date:** 2026-03-19
**Status:** Approved

## Overview

Show the total number of completed focus sessions and total focus time for the current day in the menu bar popover (MenuBarView). Stats persist across app restarts and reset automatically at midnight.

## Requirements

- Display daily focus session count and total focus time in the popover
- A session is counted only when the focus timer naturally runs out (not manual skips)
- Stats persist across app restarts using UserDefaults
- Stats reset at midnight, including while the app is running
- Placement: below the Settings/Quit footer row, separated by a divider

## Architecture

### Data model (in `TimerViewModel`)

Three new properties backed by UserDefaults:

| Property | UserDefaults key | Type | Purpose |
|---|---|---|---|
| `dailyFocusSessions` | `dailyFocusSessions` | `Int` | Count of completed focus sessions today |
| `dailyFocusSeconds` | `dailyFocusSeconds` | `Int` | Total focus time in seconds today |
| `statsDate` | `statsDate` | `String` | ISO date string (e.g. `"2026-03-19"`) for the current stats day |

### Reset logic

On `init()`: compare `statsDate` from UserDefaults to today's date string. If they differ (new day or first launch), reset `dailyFocusSessions` and `dailyFocusSeconds` to `0` and update `statsDate`.

In `tick()`: each second, compare the current date string to `statsDate`. If the day has rolled over (app open through midnight), reset all stats and update `statsDate`.

### Session recording

In `tick()`, when `remainingSeconds` reaches `0` and the completing mode is `.focus`:
1. Increment `dailyFocusSessions` by 1
2. Add `timerDurationMinutes * 60` to `dailyFocusSeconds` — this equals the full session duration since the timer ran to zero naturally
3. Persist both to UserDefaults

This happens before the existing mode-switch and `onFinish` call.

## UI

### Stats row in `MenuBarView`

Appended below the existing `Divider` + Settings/Quit `HStack`, separated by another `Divider`:

```
[Divider]
Settings                    Quit
[Divider]
🍅 3 sessions          60 min today
```

- Font: `.caption` or 11pt, `.secondary` foreground color — subtle, not distracting
- Always visible (even at 0 sessions)

### Time formatting

| Total seconds | Display |
|---|---|
| 0–3599 | `N min today` (e.g. `60 min today`) |
| 3600+ | `Nh Nm today` (e.g. `1h 20m today`) |

### Edge cases

- **Zero sessions:** Shows `🍅 0 sessions` on the left and `0 min today` on the right (same two-column layout as non-zero) — always rendered so the row is always present
- **First launch / no stats yet:** Treated as 0 sessions (defaults to `0` in UserDefaults)

## Files Changed

- `sprout-pomodoro/TimerViewModel.swift` — add stats properties, reset logic in `init()` and `tick()`, increment on session complete
- `sprout-pomodoro/MenuBarView.swift` — add stats row below footer divider
