# Persistent Focus Session Storage Design

**Date:** 2026-03-20
**Status:** Approved

## Goal

Replace the UserDefaults-based daily stats (from the `2026-03-19-daily-stats` plan) with a SwiftData store that persists individual focus session records permanently. This enables bar/line charts, calendar heatmaps, and streak tracking across all historical data.

---

## Data Model

**New file:** `sprout-pomodoro/FocusSession.swift`
**Delete:** `sprout-pomodoro/Item.swift` (unused placeholder)
**Delete:** `sprout-pomodoro/ContentView.swift` (Xcode boilerplate; references `Item` via `@Query`, not used anywhere in the running app)

```swift
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

- `startedAt`: the moment the focus timer hits zero (session completion time)
- `durationSeconds`: `timerDurationMinutes * 60` at time of completion — always a whole number of minutes, so sub-minute rounding is never a concern

All aggregates (daily totals, streaks, heatmap data) are derived from these raw records — no separate aggregate tables.

---

## Architecture

### App Wiring

In `sprout_pomodoroApp.swift`, add `.modelContainer(for: FocusSession.self)` to the `MenuBarExtra` scene. SwiftData stores data in the app's Application Support directory automatically.

`@Environment(\.modelContext)` is only accessible from `View` structs, not from the `App` struct itself. Therefore, the one-time setup call lives in **`MenuBarView`**, not in `sprout_pomodoroApp.swift`. `MenuBarView` declares `@Environment(\.modelContext) private var modelContext` and calls `timerViewModel.setupIfNeeded` from its `onAppear`.

`onAppear` on `MenuBarExtra` content views fires every time the popover opens. The actual fix for preventing repeated setup is the **`isSetUp` guard** inside `setupIfNeeded` — the location (`MenuBarView`) just makes the `ModelContext` environment value accessible. Without the guard, moving to `MenuBarView` alone would not prevent re-assignment.

```swift
// MenuBarView.swift
@Environment(\.modelContext) private var modelContext

.onAppear {
    timerViewModel.setupIfNeeded(context: modelContext) { completedMode in
        switch completedMode {
        case .focus: NotificationManager.shared.sendFocusFinishedNotification()
        case .breakTime: NotificationManager.shared.sendBreakFinishedNotification()
        }
    }
}
```

```swift
// TimerViewModel
func setupIfNeeded(context: ModelContext, onFinish: @escaping (TimerMode) -> Void) {
    guard !isSetUp else { return }
    isSetUp = true
    self.modelContext = context
    self.onFinish = onFinish
    refreshTodaySessions()  // rehydrates todaySessions from the store on startup
}
```

Remove the `onFinish` assignment from `sprout_pomodoroApp.swift`'s `onAppear` entirely — it moves into `setupIfNeeded` via `MenuBarView`.

### TimerViewModel Changes

**Remove entirely:**
- `@Published var dailyFocusSessions: Int` (stored published property — replaced by a computed property below)
- `@Published var dailyFocusSeconds: Int`
- `var statsDate: String`
- `func resetDailyStats()`
- `var todayDateString: String` (computed property)
- All UserDefaults reads/writes for stats keys (`dailyFocusSessions`, `dailyFocusSeconds`, `statsDate`)
- Midnight-reset check in `tick()`

**Add:**
- `private var isSetUp = false`
- `private var modelContext: ModelContext?`
- `func setupIfNeeded(context:onFinish:)` — guards `isSetUp`, stores both, calls `refreshTodaySessions()`
- `@Published var todaySessions: [FocusSession] = []` — the source of truth for today's stats; views observing it re-render automatically via `ObservableObject`
- `private func refreshTodaySessions()` — fetches today's sessions from the store (see implementation below). On app restart within the same day, this rehydrates `todaySessions` with persisted records — replacing the role that UserDefaults integers previously served. If fetch throws, log and leave `todaySessions` unchanged.
- On focus session completion in `tick()`: guard with `guard let context = modelContext else { return }` — this is the backstop for any code path that reaches `tick()` before `setupIfNeeded` is called (e.g. in tests that don't inject a context). In the real app this never fires because the timer UI lives inside `MenuBarView`, which calls `setupIfNeeded` in `onAppear` before the user can interact with any controls. Then insert the session and call `refreshTodaySessions()`. Rely on SwiftData's autosave — no explicit `context.save()` call needed.

**`refreshTodaySessions` implementation:**

```swift
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
```

**Computed properties (derived from `todaySessions`):**

`dailyFocusSessions` becomes a plain computed property (not `@Published`). View updates are driven by `@Published var todaySessions` changing — no annotation needed on the computed property itself. `MenuBarView` does not currently reference `dailyFocusSessions` (the stats row UI is future work), so no view changes are needed in this PR for this property:

```swift
var dailyFocusSessions: Int { todaySessions.count }
```

`formattedDailyTime` is a new computed property. Because `durationSeconds` is always `timerDurationMinutes * 60`, all values are whole-minute multiples — sub-minute remainders never occur:

```swift
var formattedDailyTime: String {
    let total = todaySessions.reduce(0) { $0 + $1.durationSeconds }
    let hours = total / 3600
    let mins = (total % 3600) / 60
    if hours > 0 {
        return mins > 0 ? "\(hours)h \(mins)m today" : "\(hours)h today"
    }
    return "\(mins) min today"
}
```

Formats as: `"0 min today"` (zero), `"45 min today"` (under 1h), `"1h today"` (exactly 1h), `"1h 20m today"` (over 1h).

### Chart Data Access

Chart and stats views use dynamic `@Query` predicates by passing the filter through `init`. SwiftData's `#Predicate` macro does not support capturing arbitrary local variables at property-wrapper initialisation time, so views must use the `_sessions = Query(filter:)` pattern:

```swift
struct RecentSessionsView: View {
    @Query private var sessions: [FocusSession]

    init(since date: Date) {
        _sessions = Query(filter: #Predicate<FocusSession> { $0.startedAt >= date })
    }
}
```

The parent view computes the cutoff date (e.g. `Calendar.current.date(byAdding: .day, value: -7, to: Date())!`) and passes it to the child view's `init`. This pattern works for bar/line charts, heatmaps, and streak calculations.

From session arrays, all three visualisations are derivable:
- **Bar/line chart:** group by `Calendar.current.startOfDay(for:)`, sum `durationSeconds` per day
- **Calendar heatmap:** same grouping, count sessions or sum minutes per day
- **Streak:** find longest (or current) consecutive sequence of days with ≥ 1 session

No additional aggregation models are needed.

---

## Testing

SwiftData is available to the test bundle via `@testable import sprout_pomodoro` — the test bundle is hosted in the app process, which already links SwiftData implicitly. No explicit framework linkage change to `project.pbxproj` is needed.

Use an **in-memory `ModelContainer`** for test isolation:

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: FocusSession.self, configurations: config)
let context = container.mainContext
```

All tests that exercise `tick()` to completion must call `vm.setupIfNeeded(context: context, onFinish: { _ in })` first. Without an injected context, the `guard let context = modelContext else { return }` in `tick()` silently skips the insert — the guard is a runtime safety backstop, not an intended code path, so tests must not rely on it. Tests that do not drive `tick()` to zero do not need context injection.

**Delete `DailyStatsTests` in its entirety** — it tests `dailyFocusSessions`, `dailyFocusSeconds`, and `statsDate` as UserDefaults-backed stored properties, all of which are being removed. Replace it with a new `FocusSessionTests` class covering:
- Session inserted into context on focus completion
- No session inserted on break completion
- `dailyFocusSessions` returns correct count after multiple completions
- `formattedDailyTime`: zero, under one hour, exactly one hour, over one hour
- `refreshTodaySessions` excludes sessions from previous days

Existing `TimerViewModelTests`: remove any UserDefaults isolation setup; call `setupIfNeeded(context:onFinish:)` in `setUp()` for tests that drive `tick()` to zero.

---

## Files Changed

| File | Change |
|---|---|
| `sprout-pomodoro/FocusSession.swift` | New — SwiftData model |
| `sprout-pomodoro/Item.swift` | Deleted |
| `sprout-pomodoro/ContentView.swift` | Deleted (unused boilerplate referencing `Item`) |
| `sprout-pomodoro/TimerViewModel.swift` | Remove UserDefaults stats; add `setupIfNeeded`, `isSetUp`, `modelContext`, session writing, `todaySessions`, `refreshTodaySessions`, computed properties |
| `sprout-pomodoro/MenuBarView.swift` | Add `@Environment(\.modelContext)`; call `setupIfNeeded` in `onAppear`; remove `onFinish` from `sprout_pomodoroApp.swift` |
| `sprout-pomodoro/sprout_pomodoroApp.swift` | Add `.modelContainer(for: FocusSession.self)`; remove `onFinish` assignment from `onAppear` |
| `sprout-pomodoroTests/sprout_pomodoroTests.swift` | Delete `DailyStatsTests`; add `FocusSessionTests` with in-memory ModelContainer; update `TimerViewModelTests` to inject context |

---

## What This Supersedes

The `2026-03-19-daily-stats` implementation plan is superseded by this design. Any partially-implemented UserDefaults stats code from that plan should be removed as part of this work.
