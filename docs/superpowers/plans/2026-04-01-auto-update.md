# Auto-Update Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lightweight version check that hits the GitHub Releases API on launch and every 24 hours, and shows a native alert when a newer version is available, opening the release page in the browser when the user clicks "Update".

**Architecture:** A new `UpdateChecker` (`@MainActor ObservableObject`) owns all update logic — fetch, parse, compare, and expose `availableUpdate`. It is created as a `@StateObject` in the App, passed via `environmentObject`, and `MenuBarView` shows a native SwiftUI `.alert` bound to it.

**Tech Stack:** Swift, SwiftUI, Foundation (`URLSession`, `JSONDecoder`, `Timer`), XCTest

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `sprout-pomodoro/UpdateChecker.swift` | All update logic: fetch, parse, compare, schedule |
| Modify | `sprout-pomodoro/sprout_pomodoroApp.swift` | Create `UpdateChecker` as `@StateObject`, pass via environment |
| Modify | `sprout-pomodoro/MenuBarView.swift` | Read `updateChecker` from environment, show alert |
| Create | `sprout-pomodoroTests/UpdateCheckerTests.swift` | Unit tests for parsing, comparison, fetch scenarios |

---

## Task 1: Scaffold UpdateChecker with version parsing (TDD)

**Files:**
- Create: `sprout-pomodoro/UpdateChecker.swift`
- Create: `sprout-pomodoroTests/UpdateCheckerTests.swift`

- [ ] **Step 1: Create `UpdateChecker.swift` with scaffold and pure parsing functions**

Create `sprout-pomodoro/UpdateChecker.swift`:

```swift
import Foundation

struct AvailableUpdate {
    let version: String
    let url: URL
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var availableUpdate: AvailableUpdate?

    private let appVersion: String
    private let fetcher: (URL) async throws -> Data
    private var hasStarted = false

    init(
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
        fetcher: @escaping (URL) async throws -> Data = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.appVersion = appVersion
        self.fetcher = fetcher
    }

    /// Strips a leading "v" and splits by "." into an array of Ints.
    /// "v1.2.3" → [1, 2, 3], "1.0" → [1, 0]
    static func parseVersion(_ string: String) -> [Int] {
        let stripped = string.hasPrefix("v") ? String(string.dropFirst()) : string
        return stripped.split(separator: ".").compactMap { Int($0) }
    }

    /// Returns true if tagVersion is strictly greater than appVersion.
    /// Both arrays are zero-padded to the same length before comparison.
    static func isNewer(_ tagVersion: [Int], than appVersion: [Int]) -> Bool {
        let maxLen = max(tagVersion.count, appVersion.count)
        let t = tagVersion + Array(repeating: 0, count: maxLen - tagVersion.count)
        let a = appVersion + Array(repeating: 0, count: maxLen - appVersion.count)
        for (tv, av) in zip(t, a) {
            if tv > av { return true }
            if tv < av { return false }
        }
        return false // equal
    }
}
```

- [ ] **Step 2: Create `UpdateCheckerTests.swift` with version parsing and comparison tests**

Create `sprout-pomodoroTests/UpdateCheckerTests.swift`:

```swift
import XCTest
@testable import sprout_pomodoro

@MainActor
final class UpdateCheckerTests: XCTestCase {

    // MARK: - parseVersion

    func test_parseVersion_stripsVPrefix() {
        XCTAssertEqual(UpdateChecker.parseVersion("v1.2.3"), [1, 2, 3])
    }

    func test_parseVersion_noPrefix() {
        XCTAssertEqual(UpdateChecker.parseVersion("1.0"), [1, 0])
    }

    func test_parseVersion_singleComponent() {
        XCTAssertEqual(UpdateChecker.parseVersion("2"), [2])
    }

    // MARK: - isNewer

    func test_isNewer_tagHigherMinor_returnsTrue() {
        XCTAssertTrue(UpdateChecker.isNewer([1, 2, 0], than: [1, 0, 0]))
    }

    func test_isNewer_tagHigherPatch_returnsTrue() {
        XCTAssertTrue(UpdateChecker.isNewer([1, 0, 1], than: [1, 0, 0]))
    }

    func test_isNewer_tagHigherMajor_returnsTrue() {
        XCTAssertTrue(UpdateChecker.isNewer([2, 0, 0], than: [1, 9, 9]))
    }

    func test_isNewer_sameVersion_returnsFalse() {
        XCTAssertFalse(UpdateChecker.isNewer([1, 0, 0], than: [1, 0, 0]))
    }

    func test_isNewer_tagOlder_returnsFalse() {
        XCTAssertFalse(UpdateChecker.isNewer([0, 9, 0], than: [1, 0, 0]))
    }

    func test_isNewer_differentLengths_tagIsNewer() {
        // app "1.0" ([1,0]) vs tag "v1.0.1" ([1,0,1]) → tag is newer
        XCTAssertTrue(UpdateChecker.isNewer([1, 0, 1], than: [1, 0]))
    }

    func test_isNewer_differentLengths_equal() {
        // app "1.0" ([1,0]) vs tag "v1.0.0" ([1,0,0]) → equal, not newer
        XCTAssertFalse(UpdateChecker.isNewer([1, 0, 0], than: [1, 0]))
    }
}
```

- [ ] **Step 3: Run these tests — expect them to PASS (parsing logic is already implemented)**

```bash
xcodebuild test \
  -project sprout-pomodoro.xcodeproj \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  -only-testing:sprout-pomodoroTests/UpdateCheckerTests \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: 9 tests pass. (Or run Cmd+U in Xcode and filter to `UpdateCheckerTests`.)

- [ ] **Step 4: Commit**

```bash
git add sprout-pomodoro/UpdateChecker.swift sprout-pomodoroTests/UpdateCheckerTests.swift
git commit -m "feat: add UpdateChecker scaffold with version parsing logic"
```

---

## Task 2: Implement `checkForUpdates()` (TDD)

**Files:**
- Modify: `sprout-pomodoro/UpdateChecker.swift`
- Modify: `sprout-pomodoroTests/UpdateCheckerTests.swift`

The GitHub Releases API returns JSON with at minimum:
```json
{ "tag_name": "v1.2.0", "html_url": "https://github.com/andrewchaa/sprout-pomodoro/releases/tag/v1.2.0" }
```

- [ ] **Step 1: Write failing tests for `checkForUpdates()`**

Append these test methods to `UpdateCheckerTests` in `sprout-pomodoroTests/UpdateCheckerTests.swift` (inside the class, after the existing tests):

```swift
    // MARK: - checkForUpdates

    func test_newerVersion_setsAvailableUpdate() async {
        let json = Data("""
        {"tag_name":"v2.0.0","html_url":"https://github.com/andrewchaa/sprout-pomodoro/releases/tag/v2.0.0"}
        """.utf8)
        let checker = UpdateChecker(appVersion: "1.0", fetcher: { _ in json })

        await checker.checkForUpdates()

        XCTAssertEqual(checker.availableUpdate?.version, "2.0.0")
        XCTAssertEqual(
            checker.availableUpdate?.url,
            URL(string: "https://github.com/andrewchaa/sprout-pomodoro/releases/tag/v2.0.0")
        )
    }

    func test_sameVersion_doesNotSetAvailableUpdate() async {
        let json = Data("""
        {"tag_name":"v1.0.0","html_url":"https://github.com/andrewchaa/sprout-pomodoro/releases/tag/v1.0.0"}
        """.utf8)
        let checker = UpdateChecker(appVersion: "1.0", fetcher: { _ in json })

        await checker.checkForUpdates()

        XCTAssertNil(checker.availableUpdate)
    }

    func test_olderVersion_doesNotSetAvailableUpdate() async {
        let json = Data("""
        {"tag_name":"v0.9.0","html_url":"https://github.com/andrewchaa/sprout-pomodoro/releases/tag/v0.9.0"}
        """.utf8)
        let checker = UpdateChecker(appVersion: "1.0", fetcher: { _ in json })

        await checker.checkForUpdates()

        XCTAssertNil(checker.availableUpdate)
    }

    func test_networkError_doesNotSetAvailableUpdate() async {
        let checker = UpdateChecker(
            appVersion: "1.0",
            fetcher: { _ in throw URLError(.notConnectedToInternet) }
        )

        await checker.checkForUpdates()

        XCTAssertNil(checker.availableUpdate)
    }

    func test_malformedJson_doesNotSetAvailableUpdate() async {
        let checker = UpdateChecker(appVersion: "1.0", fetcher: { _ in Data("not json".utf8) })

        await checker.checkForUpdates()

        XCTAssertNil(checker.availableUpdate)
    }
```

- [ ] **Step 2: Run tests — expect the 5 new tests to FAIL**

```bash
xcodebuild test \
  -project sprout-pomodoro.xcodeproj \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  -only-testing:sprout-pomodoroTests/UpdateCheckerTests \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: 9 pass (parsing tests), 5 fail (checkForUpdates not implemented yet).

- [ ] **Step 3: Implement `checkForUpdates()` in `UpdateChecker.swift`**

Add this private struct and the method to `UpdateChecker.swift`. Place `GitHubRelease` just above the class definition, and add `checkForUpdates()` inside the class:

```swift
// Add above the class:
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}
```

Add inside the `UpdateChecker` class, after `isNewer`:

```swift
    func checkForUpdates() async {
        let apiURL = URL(string: "https://api.github.com/repos/andrewchaa/sprout-pomodoro/releases/latest")!
        do {
            let data = try await fetcher(apiURL)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let tagComponents = Self.parseVersion(release.tagName)
            let appComponents = Self.parseVersion(appVersion)
            guard Self.isNewer(tagComponents, than: appComponents),
                  let url = URL(string: release.htmlUrl) else { return }
            let displayVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName
            availableUpdate = AvailableUpdate(version: displayVersion, url: url)
        } catch {
            // silently ignore — network errors should not surface to the user
        }
    }
```

- [ ] **Step 4: Run tests — expect all 14 tests to PASS**

```bash
xcodebuild test \
  -project sprout-pomodoro.xcodeproj \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  -only-testing:sprout-pomodoroTests/UpdateCheckerTests \
  2>&1 | grep -E "PASS|FAIL|error:"
```

Expected: 14 tests pass, 0 fail.

- [ ] **Step 5: Commit**

```bash
git add sprout-pomodoro/UpdateChecker.swift sprout-pomodoroTests/UpdateCheckerTests.swift
git commit -m "feat: implement checkForUpdates via GitHub Releases API"
```

---

## Task 3: Add `startPeriodicChecks()` and wire into the App

**Files:**
- Modify: `sprout-pomodoro/UpdateChecker.swift`
- Modify: `sprout-pomodoro/sprout_pomodoroApp.swift`

- [ ] **Step 1: Add `startPeriodicChecks()` to `UpdateChecker.swift`**

Add this method inside the `UpdateChecker` class, after `checkForUpdates()`:

```swift
    /// Calls checkForUpdates() immediately, then every 24 hours.
    /// Safe to call multiple times — subsequent calls are no-ops.
    func startPeriodicChecks() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await checkForUpdates() }
        Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.checkForUpdates() }
        }
    }
```

- [ ] **Step 2: Modify `sprout_pomodoroApp.swift` to create and expose `UpdateChecker`**

The current file is:

```swift
import SwiftUI
import SwiftData

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

Replace with:

```swift
import SwiftUI
import SwiftData

@main
struct SproutPomodoroApp: App {
    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var updateChecker = UpdateChecker()

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
                .environmentObject(updateChecker)
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

- [ ] **Step 3: Build to verify no compile errors**

```bash
xcodebuild build \
  -project sprout-pomodoro.xcodeproj \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add sprout-pomodoro/UpdateChecker.swift sprout-pomodoro/sprout_pomodoroApp.swift
git commit -m "feat: add startPeriodicChecks and wire UpdateChecker into App"
```

---

## Task 4: Add update alert to `MenuBarView`

**Files:**
- Modify: `sprout-pomodoro/MenuBarView.swift`

- [ ] **Step 1: Add `@EnvironmentObject var updateChecker: UpdateChecker` and start periodic checks**

The current `MenuBarView` starts with:

```swift
struct MenuBarView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.modelContext) private var modelContext
```

Replace those lines with:

```swift
struct MenuBarView: View {
    @EnvironmentObject var viewModel: TimerViewModel
    @EnvironmentObject var updateChecker: UpdateChecker
    @Environment(\.openSettings) private var openSettings
    @Environment(\.modelContext) private var modelContext
```

- [ ] **Step 2: Start periodic checks in `onAppear` and add the alert**

The current `.onAppear` block at the bottom of the view body is:

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
        }
```

Replace it with:

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
            updateChecker.startPeriodicChecks()
        }
        .alert("Update Available", isPresented: Binding(
            get: { updateChecker.availableUpdate != nil },
            set: { if !$0 { updateChecker.availableUpdate = nil } }
        )) {
            Button("Update") {
                if let url = updateChecker.availableUpdate?.url {
                    NSWorkspace.shared.open(url)
                }
                updateChecker.availableUpdate = nil
            }
            Button("Later", role: .cancel) {
                updateChecker.availableUpdate = nil
            }
        } message: {
            if let update = updateChecker.availableUpdate {
                Text("Version \(update.version) is available. Would you like to update?")
            }
        }
```

- [ ] **Step 3: Build and run the app**

```bash
xcodebuild build \
  -project sprout-pomodoro.xcodeproj \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

Then run the app in Xcode (Cmd+R).

- [ ] **Step 4: Manually test the alert**

To verify the alert works without waiting for a real GitHub release, temporarily replace the `UpdateChecker()` init in `sprout_pomodoroApp.swift` with a mock:

```swift
// TEMPORARY TEST — revert after verifying
@StateObject private var updateChecker = UpdateChecker(
    appVersion: "0.0.1",
    fetcher: { _ in
        Data("""
        {"tag_name":"v1.0.0","html_url":"https://github.com/andrewchaa/sprout-pomodoro/releases"}
        """.utf8)
    }
)
```

Run the app. The alert "Update Available — Version 1.0.0 is available." should appear immediately when the menu bar popover opens. Click "Update" — the browser should open the releases page. Click "Later" — the alert should dismiss.

After verifying, revert the temporary change:

```swift
@StateObject private var updateChecker = UpdateChecker()
```

- [ ] **Step 5: Run the full test suite to make sure nothing is broken**

```bash
xcodebuild test \
  -project sprout-pomodoro.xcodeproj \
  -scheme sprout-pomodoro \
  -destination 'platform=macOS' \
  2>&1 | grep -E "PASS|FAIL|error:|BUILD FAILED"
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add sprout-pomodoro/MenuBarView.swift
git commit -m "feat: show update alert in menu bar popover when new version is available"
```

---

## Summary

| Task | What it delivers |
|------|-----------------|
| Task 1 | `UpdateChecker` skeleton + version parsing, fully tested |
| Task 2 | `checkForUpdates()` fetches GitHub API + all fetch scenarios tested |
| Task 3 | 24h periodic checks wired into App lifecycle |
| Task 4 | Native alert in `MenuBarView`, opens browser on "Update" |
