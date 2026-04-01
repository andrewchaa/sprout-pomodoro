//
//  sprout_pomodoroApp.swift
//  sprout-pomodoro
//

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
